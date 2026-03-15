class TrackMailer < ApplicationMailer
  def stems_ready(track)
    @track = track
    @user  = track.user
    mail(to: @user.email_address, subject: "Your stems are ready — #{track.name}")
  end

  def processing_failed(track)
    @track = track
    @user  = track.user
    mail(to: @user.email_address, subject: "Processing failed — #{track.name}")
  end
end
