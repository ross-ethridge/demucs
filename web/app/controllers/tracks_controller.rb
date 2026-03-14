class TracksController < ApplicationController
  before_action :set_track, only: [:show, :destroy, :download_stem]

  def index
    @tracks = Track.order(created_at: :desc)
  end

  def new
    @track = Track.new(model: "htdemucs")
  end

  def create
    uploaded = params[:track][:audio_file]
    return redirect_to new_track_path, alert: "Please select a file." unless uploaded

    blob     = ActiveStorage::Blob.find_signed!(uploaded)
    original = blob.filename.sanitized
    filename = "#{SecureRandom.hex(8)}_#{original}"

    @track = Track.new(
      name:     params[:track][:name].presence || File.basename(original, File.extname(original)),
      filename: filename,
      model:    Track::MODELS.key?(params[:track][:model]) ? params[:track][:model] : "htdemucs"
    )
    @track.audio_file.attach(blob)

    if @track.save
      ProcessTrackJob.perform_later(@track.id)
      redirect_to @track, notice: "Track uploaded and queued for processing."
    else
      redirect_to new_track_path, alert: @track.errors.full_messages.to_sentence
    end
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

  def download_stem
    unless Track::STEMS.include?(params[:stem])
      return head :bad_request
    end

    if S3Storage.configured?
      redirect_to S3Storage.presigned_url(@track, params[:stem]), allow_other_host: true
    else
      path = @track.stem_path(params[:stem])
      send_file path, filename: "#{@track.stem_name}_#{params[:stem]}.wav", type: "audio/wav", disposition: "attachment"
    end
  end

  private

  def set_track
    @track = Track.find(params[:id])
  end
end
