require "open3"

class ProcessTrackJob < ApplicationJob
  queue_as :default

  def perform(track_id)
    track = Track.find(track_id)
    track.update!(status: "processing", progress: 0)

    dest = File.join(Rails.application.config.demucs_input_path, track.filename)
    FileUtils.mkdir_p(Rails.application.config.demucs_input_path)
    Rails.logger.info("[ProcessTrackJob] Downloading input: #{track.filename}")
    File.open(dest, "wb") { |f| track.audio_file.download { |chunk| f.write(chunk) } }

    cmd = build_docker_cmd(track)
    Rails.logger.info("[ProcessTrackJob] Running: #{cmd}")
    success = run_with_progress(cmd, track)

    if success
      trim_stems(track)
      if S3Storage.configured?
        upload_stems(track)
        FileUtils.rm_rf(local_output_dir(track))
      end
      track.audio_file.purge
      FileUtils.rm_f(dest)
      track.update!(status: "done", progress: 100)
    else
      track.update!(status: "failed", progress: track.progress)
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error("[ProcessTrackJob] Track #{track_id} not found")
  rescue => e
    Rails.logger.error("[ProcessTrackJob] #{e.class}: #{e.message}")
    track&.update!(status: "failed")
  end

  private

  def run_with_progress(cmd, track)
    exit_status = nil
    run_index  = 0
    last_pct   = -1
    buf        = ""

    Open3.popen2e(cmd) do |stdin, output, wait_thr|
      stdin.close
      loop do
        begin
          buf += output.readpartial(2048)
          while (idx = buf.index(/[\r\n]/))
            segment = buf[0, idx].strip
            buf     = buf[idx + 1..]
            next if segment.empty?

            if (match = segment.match(/(\d+)%\|/))
              per_model_pct = match[1].to_i
              run_index += 1 if per_model_pct < last_pct
              last_pct = per_model_pct
              overall  = ((run_index * 100 + per_model_pct) / 4.0).round
              track.update!(progress: overall) if overall != track.progress
            else
              Rails.logger.info("[ProcessTrackJob] demucs: #{segment}")
            end
          end
        rescue EOFError
          break
        end
      end
      exit_status = wait_thr.value
    end
    exit_status.success?
  end

  def trim_stems(track)
    track.stems.each do |stem|
      path = track.stem_path(stem)
      next unless File.exist?(path)

      tmp = "#{path}.tmp.wav"
      cmd = "ffmpeg -i #{Shellwords.escape(path)} -af silenceremove=stop_periods=-1:stop_duration=1:stop_threshold=-50dB #{Shellwords.escape(tmp)} -y 2>/dev/null"
      if system(cmd) && File.exist?(tmp)
        FileUtils.mv(tmp, path)
        Rails.logger.info("[ProcessTrackJob] Trimmed silence from #{stem}")
      else
        FileUtils.rm_f(tmp)
        Rails.logger.warn("[ProcessTrackJob] ffmpeg trim failed for #{stem}, keeping original")
      end
    end
  end

  def upload_stems(track)
    track.stems.each do |stem|
      local = track.stem_path(stem)
      Rails.logger.info("[ProcessTrackJob] Uploading #{stem} to S3")
      S3Storage.upload(track, stem, local)
    end
  end

  def local_output_dir(track)
    File.join(Rails.application.config.demucs_output_path,
              track.model, track.stem_name)
  end

  def build_docker_cmd(track)
    config = Rails.application.config

    image       = ENV.fetch("DEMUCS_IMAGE", config.demucs_image)
    gpu         = ENV.fetch("DEMUCS_GPU", "false") == "true"
    use_volumes = ENV.fetch("DEMUCS_USE_VOLUMES", "false") == "true"

    if use_volumes
      input_vol  = ENV.fetch("DEMUCS_INPUT_VOLUME",  "demucs_input")
      output_vol = ENV.fetch("DEMUCS_OUTPUT_VOLUME", "demucs_output")
      models_vol = ENV.fetch("DEMUCS_MODELS_VOLUME", "demucs_models")
      v_input  = "#{input_vol}:/data/input"
      v_output = "#{output_vol}:/data/output"
      v_models = "#{models_vol}:/data/models"
    else
      input_path  = File.expand_path(ENV.fetch("DEMUCS_INPUT_PATH",  config.demucs_input_path))
      output_path = File.expand_path(ENV.fetch("DEMUCS_OUTPUT_PATH", config.demucs_output_path))
      models_path = File.expand_path(ENV.fetch("DEMUCS_MODELS_PATH", config.demucs_models_path))
      v_input  = "#{input_path}:/data/input"
      v_output = "#{output_path}:/data/output"
      v_models = "#{models_path}:/data/models"
    end

    gpu_flag       = gpu ? "--gpus all" : ""
    threads        = ENV.fetch("DEMUCS_THREADS", "4")
    shifts         = ENV.fetch("DEMUCS_SHIFTS", "1")
    container_name = "demucs-#{track.id}"
    quoted_file    = Shellwords.escape("/data/input/#{track.filename}")

    [
      "docker run --rm -i",
      gpu_flag,
      "--name=#{container_name}",
      "-e PYTHONUNBUFFERED=1",
      "-e OMP_NUM_THREADS=#{threads}",
      "-v #{v_input}",
      "-v #{v_output}",
      "-v #{v_models}",
      image,
      %Q("python3 -m demucs -n #{track.model} --out /data/output --shifts #{shifts} --overlap 0.25 -j 1 #{quoted_file}")
    ].reject(&:empty?).join(" ")
  end
end
