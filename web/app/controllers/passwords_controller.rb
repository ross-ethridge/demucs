class PasswordsController < ApplicationController
  def edit; end

  def update
    if Current.session.user.update(password_params)
      redirect_to tracks_path, notice: "Password updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
