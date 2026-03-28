require "net/http"
require "json"

class ProcessTrackJob < ApplicationJob
  queue_as :default

  DEMUCS_ENDPOINT = ENV.fetch("DEMUCS_ENDPOINT", "http://demucs:8080")

  def perform(track_id)
    track = Track.find(track_id)
    track.update!(status: "processing", progress: 0)

    submit_job(track)
    poll_until_done(track)

    track.audio_file.purge
    track.update!(status: "done", progress: 100)
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error("[ProcessTrackJob] Track #{track_id} not found")
  rescue => e
    Rails.logger.error("[ProcessTrackJob] #{e.class}: #{e.message}")
    track&.update!(status: "failed")
  end

  private

  def submit_job(track)
    uri      = URI("#{DEMUCS_ENDPOINT}/jobs")
    req      = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    req.body = {
      job_id:    track.id.to_s,
      bucket:    ENV.fetch("AWS_BUCKET"),
      input_key: track.audio_file.key,
      filename:  track.filename,
      model:     track.model,
      shifts:    ENV.fetch("DEMUCS_SHIFTS", "1").to_i
    }.to_json
    Net::HTTP.start(uri.host, uri.port) { |h| h.request(req) }
  end

  def poll_until_done(track)
    uri = URI("#{DEMUCS_ENDPOINT}/jobs/#{track.id}")
    loop do
      body = JSON.parse(Net::HTTP.get(uri))
      track.update!(progress: body["progress"].to_i) if body["progress"]
      case body["status"]
      when "done"   then return
      when "failed" then raise "demucs failed: #{body["error"]}"
      end
      sleep 5
    end
  end
end
