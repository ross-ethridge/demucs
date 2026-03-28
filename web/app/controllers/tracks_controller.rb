class TracksController < ApplicationController
  before_action :set_track, only: [:show, :destroy, :download_stem, :stream_stem]
  rate_limit to: 10, within: 10.minutes, only: :create, with: -> { redirect_to new_track_path, alert: "Too many uploads. Try again later." }

  def index
    @tracks = current_user.tracks.order(created_at: :desc)
  end

  def new
    @track = Track.new(model: "htdemucs_ft")
  end

  def create
    uploaded_file = params[:track][:audio_file]
    return redirect_to new_track_path, alert: "Please select a file." unless uploaded_file

    if uploaded_file.size > 500.megabytes
      return redirect_to new_track_path, alert: "File is too large. Maximum size is 500 MB."
    end

    blob = ActiveStorage::Blob.create_and_upload!(
      io:           uploaded_file,
      filename:     uploaded_file.original_filename,
      content_type: uploaded_file.content_type
    )

    original = blob.filename.sanitized
    model    = Track::MODELS.key?(params[:track][:model]) ? params[:track][:model] : "htdemucs_ft"
    name     = params[:track][:name].presence || File.basename(original, File.extname(original))
    filename = "#{SecureRandom.hex(8)}_#{original}"

    track = Track.new(name: name, filename: filename, model: model, user: current_user)
    track.audio_file.attach(blob)
    track.save!
    ProcessTrackJob.perform_later(track.id)
    redirect_to track, notice: "Your track is queued for processing."
  end

  def show
  end

  def destroy
    @track.destroy
    S3Storage.delete(@track) if S3Storage.configured?
    rescue => e
      Rails.logger.error("[destroy] Cleanup failed for track #{@track.id}: #{e.message}")
    ensure
      redirect_to tracks_path, notice: "Track deleted."
  end

  def stream_stem
    unless Track::STEMS.include?(params[:stem])
      return head :bad_request
    end

    if S3Storage.configured?
      range = request.headers["Range"]
      if range
        total  = S3Storage.size(@track, params[:stem])
        m      = range.match(/bytes=(\d+)-(\d*)/)
        s      = m[1].to_i
        e      = m[2].present? ? m[2].to_i : total - 1
        data   = S3Storage.fetch_range(@track, params[:stem], range)
        response.status = 206
        response.headers["Content-Type"]  = "audio/wav"
        response.headers["Content-Range"] = "bytes #{s}-#{e}/#{total}"
        response.headers["Accept-Ranges"] = "bytes"
        render body: data
      else
        response.headers["Accept-Ranges"] = "bytes"
        send_data S3Storage.fetch(@track, params[:stem]), type: "audio/wav", disposition: "inline"
      end
    else
      send_file @track.stem_path(params[:stem]), type: "audio/wav", disposition: "inline"
    end
  end

  def download_stem
    unless Track::STEMS.include?(params[:stem])
      return head :bad_request
    end

    filename = "#{@track.stem_name}_#{params[:stem]}.wav"
    if S3Storage.configured?
      send_data S3Storage.fetch(@track, params[:stem]),
                type: "audio/wav", disposition: "attachment", filename: filename
    else
      send_file @track.stem_path(params[:stem]), type: "audio/wav", disposition: "attachment", filename: filename
    end
  end

  private

  def set_track
    @track = current_user.tracks.find(params[:id])
  end
end
