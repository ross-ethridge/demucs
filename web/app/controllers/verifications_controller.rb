class VerificationsController < ApplicationController
  skip_before_action :require_authentication, only: [:show]

  def show
    user = User.find_by_token_for(:email_verification, params[:token])
    if user
      user.update!(email_verified_at: Time.current)
      start_new_session_for(user) unless Current.session
      redirect_to tracks_path, notice: "Email verified! Welcome to demucs:r."
    else
      redirect_to new_session_path, alert: "Verification link is invalid or has expired."
    end
  end

  def unverified
    redirect_to tracks_path if current_user.email_verified?
  end

  def resend
    UserMailer.verify_email(current_user).deliver_later
    redirect_to unverified_path, notice: "Verification email resent — check your inbox."
  end
end
