class TracksController < ApplicationController
  before_action :set_track, only: [:show, :destroy, :download_stem]

  def index
    @tracks = current_user.tracks.order(created_at: :desc)
  end

  def new
    @track = Track.new(model: "htdemucs")
  end

  def create
    uploaded = params[:track][:audio_file]
    return redirect_to new_track_path, alert: "Please select a file." unless uploaded

    blob     = ActiveStorage::Blob.find_signed!(uploaded)
    original = blob.filename.sanitized
    model    = Track::MODELS.key?(params[:track][:model]) ? params[:track][:model] : "htdemucs"
    name     = params[:track][:name].presence || File.basename(original, File.extname(original))
    filename = "#{SecureRandom.hex(8)}_#{original}"

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
      success_url: payments_success_url(session_id: "{CHECKOUT_SESSION_ID}"),
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
