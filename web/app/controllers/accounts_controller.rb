class AccountsController < ApplicationController
  def show
  end

  def destroy
    email = current_user.email_address
    current_user.destroy
    UserMailer.account_deleted(email).deliver_later
    cookies.delete(:session_id)
    redirect_to root_path, notice: "Your account has been deleted."
  end
end
