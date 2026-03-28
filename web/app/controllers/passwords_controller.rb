class PasswordsController < ApplicationController
  allow_unauthenticated_access

  before_action :set_user_by_token, only: %i[edit update]

  # GET /passwords/new — "forgot password" form
  def new; end

  # POST /passwords — send reset email
  def create
    user = User.find_by(email_address: params[:email_address])
    UserMailer.password_reset(user).deliver_later if user
    redirect_to new_session_path, notice: "If that address is on file you'll receive a reset link shortly."
  end

  # GET /passwords/edit?token=...
  def edit; end

  # PATCH /passwords — save new password
  def update
    if @user.update(params.permit(:password, :password_confirmation))
      redirect_to new_session_path, notice: "Password updated. Please sign in."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user_by_token
    @user = User.find_by_token_for(:password_reset, params[:token])
    redirect_to new_passwords_path, alert: "Reset link is invalid or has expired." unless @user
  end
end
