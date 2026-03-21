class TracksController < ApplicationController
  before_action :require_verified_email
  before_action :set_track, only: [:show, :destroy, :download_stem]
  rate_limit to: 10, within: 10.minutes, only: :create, with: -> { redirect_to new_track_path, alert: "Too many uploads. Try again later." }

  def index
    @tracks = current_user.tracks.order(created_at: :desc)
  end

  def new
    @track = Track.new(model: "htdemucs_ft")
  end

  def create
    uploaded = params[:track][:audio_file]
    return redirect_to new_track_path, alert: "Please select a file." unless uploaded

    blob     = ActiveStorage::Blob.find_signed!(uploaded)

    if blob.byte_size > 500.megabytes
      blob.purge
      return redirect_to new_track_path, alert: "File is too large. Maximum size is 500 MB."
    end

    original = blob.filename.sanitized
    model    = Track::MODELS.key?(params[:track][:model]) ? params[:track][:model] : "htdemucs_ft"
    name     = params[:track][:name].presence || File.basename(original, File.extname(original))
    filename = "#{SecureRandom.hex(8)}_#{original}"

    if ENV["FREE_MODE"] == "true"
      blob = ActiveStorage::Blob.find_signed!(uploaded)
      track = Track.new(name: name, filename: filename, model: model, user: current_user)
      track.audio_file.attach(blob)
      track.save!
      ProcessTrackJob.perform_later(track.id)
      return redirect_to track, notice: "Your track is queued for processing."
    end

    price_id = Track::STRIPE_PRICES.fetch(model)

    session = Stripe::Checkout::Session.create(
      mode: "payment",
      line_items: [{ price: price_id, quantity: 1 }],
      metadata: {
        blob_signed_id: uploaded,
        filename:       filename,
        name:           name,
        model:          model,
        user_id:        current_user.id
      },
      success_url: "#{payments_success_url}?session_id={CHECKOUT_SESSION_ID}",
      cancel_url:  payments_cancel_url
    )

    redirect_to session.url, allow_other_host: true
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
    @track = current_user.tracks.find(params[:id])
  end
end
