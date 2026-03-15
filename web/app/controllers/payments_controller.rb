class PaymentsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:webhook]
  skip_before_action :require_authentication, only: [:webhook]
  before_action :require_verified_email, except: [:webhook]

  def success
    checkout_session = Stripe::Checkout::Session.retrieve(params[:session_id])

    unless checkout_session.payment_status == "paid"
      return redirect_to new_track_path, alert: "Payment incomplete. Please try again."
    end

    unless checkout_session.metadata.user_id.to_i == current_user.id
      return redirect_to new_track_path, alert: "Session mismatch. Please try again."
    end

    track = find_or_create_track(checkout_session)
    redirect_to track, notice: "Payment received — your track is queued for processing."
  rescue => e
    Rails.logger.error("[PaymentsController#success] #{e.message}")
    redirect_to new_track_path, alert: "Something went wrong. Please contact support."
  end

  def cancel
    redirect_to new_track_path, notice: "Payment cancelled."
  end

  def webhook
    payload    = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
    event      = Stripe::Webhook.construct_event(payload, sig_header, ENV["STRIPE_WEBHOOK_SECRET"])

    find_or_create_track(event.data.object) if event.type == "checkout.session.completed"

    head :ok
  rescue Stripe::SignatureVerificationError => e
    Rails.logger.error("[PaymentsController#webhook] Invalid signature: #{e.message}")
    head :bad_request
  rescue => e
    Rails.logger.error("[PaymentsController#webhook] #{e.message}")
    head :unprocessable_entity
  end

  private

  def find_or_create_track(checkout_session)
    return nil unless checkout_session.payment_status == "paid"

    Track.find_by(stripe_session_id: checkout_session.id) || begin
      meta = checkout_session.metadata
      user = User.find(meta.user_id)
      blob = ActiveStorage::Blob.find_signed!(meta.blob_signed_id)

      track = Track.new(
        name:              meta.name,
        filename:          meta.filename,
        model:             meta.model,
        user:              user,
        stripe_session_id: checkout_session.id
      )
      track.audio_file.attach(blob)
      track.save!
      ProcessTrackJob.perform_later(track.id)
      track
    end
  rescue ActiveRecord::RecordNotUnique
    Track.find_by(stripe_session_id: checkout_session.id)
  end
end
