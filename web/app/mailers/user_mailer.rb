class UserMailer < ApplicationMailer
  def welcome(user)
    @user = user
    mail to: @user.email_address, subject: "Welcome to demucs:r"
  end

  def password_reset(user)
    @user = user
    @token = user.generate_token_for(:password_reset)
    mail to: @user.email_address, subject: "Reset your password"
  end
end
