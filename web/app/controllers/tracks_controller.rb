class TracksController < ApplicationController
  before_action :set_track, only: [:show, :destroy, :download_stem]

  def index
    @tracks = Track.order(created_at: :desc)
  end

  def new
    @track = Track.new
  end

  def presign
    original = params[:filename].to_s.gsub(/[^\w.\-]/, "_")
    filename = "#{SecureRandom.hex(8)}_#{original}"
    key      = S3Storage.input_key(filename)
    url      = S3Storage.presigned_upload_url(key)
    render json: { url: url, filename: filename }
  end

  def create
    if params[:filename].present?
      # Direct S3 upload path — file is already in S3, just save metadata
      original = params[:filename].to_s
      @track = Track.new(
        name:     params[:name].presence || File.basename(original, File.extname(original)),
        filename: original,
        model:    Track::MODELS.key?(params[:model]) ? params[:model] : "htdemucs"
      )
    else
      # Fallback: traditional multipart upload (local dev without S3)
      uploaded = params[:track][:file]
      return redirect_to new_track_path, alert: "Please select a file." unless uploaded

      original = uploaded.original_filename
      filename = "#{SecureRandom.hex(8)}_#{original}"
      dest = File.join(Rails.application.config.demucs_input_path, filename)
      FileUtils.mkdir_p(Rails.application.config.demucs_input_path)
      File.binwrite(dest, uploaded.read)

      @track = Track.new(
        name:     params[:track][:name].presence || File.basename(original, File.extname(original)),
        filename: filename,
        model:    Track::MODELS.key?(params[:track][:model]) ? params[:track][:model] : "htdemucs"
      )
    end

    if @track.save
      ProcessTrackJob.perform_later(@track.id)
      if request.format.json?
        render json: { redirect: track_url(@track) }, status: :created
      else
        redirect_to @track, notice: "Track uploaded and queued for processing."
      end
    else
      if request.format.json?
        render json: { errors: @track.errors.full_messages }, status: :unprocessable_entity
      else
        redirect_to new_track_path, alert: @track.errors.full_messages.to_sentence
      end
    end
  end

  def show
  end

  def destroy
    @track.destroy
    input_file = File.join(Rails.application.config.demucs_input_path, @track.filename)
    output_dir = File.join(Rails.application.config.demucs_output_path, @track.model, @track.stem_name)
    FileUtils.rm_f(input_file)
    FileUtils.rm_rf(output_dir)
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
