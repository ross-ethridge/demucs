class UserMailer < ApplicationMailer
  def verify_email(user)
    @user  = user
    @token = user.generate_token_for(:email_verification)
    mail to: user.email_address, subject: "Verify your email — demucs:r"
  end

  def account_deleted(email)
    @email = email
    mail to: email, subject: "Your demucs:r account has been deleted"
  end
end
