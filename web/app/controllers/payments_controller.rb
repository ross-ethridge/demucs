class PaymentsController < ApplicationController
  def success
    checkout_session = Stripe::Checkout::Session.retrieve(params[:session_id])

    unless checkout_session.payment_status == "paid"
      return redirect_to new_track_path, alert: "Payment incomplete. Please try again."
    end

    meta = checkout_session.metadata

    unless meta.user_id.to_i == current_user.id
      return redirect_to new_track_path, alert: "Session mismatch. Please try again."
    end

    blob = ActiveStorage::Blob.find_signed!(meta.blob_signed_id)

    track = Track.new(
      name:     meta.name,
      filename: meta.filename,
      model:    meta.model,
      user:     current_user
    )
    track.audio_file.attach(blob)
    track.save!

    ProcessTrackJob.perform_later(track.id)

    redirect_to track, notice: "Payment received — your track is queued for processing."
  rescue Stripe::InvalidRequestError, ActiveRecord::RecordNotFound => e
    Rails.logger.error("[PaymentsController#success] #{e.message}")
    redirect_to new_track_path, alert: "Something went wrong. Please contact support."
  end

  def cancel
    redirect_to new_track_path, notice: "Payment cancelled."
  end
end
