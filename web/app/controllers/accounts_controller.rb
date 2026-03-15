class AccountsController < ApplicationController
  def show
  end

  def destroy
    current_user.destroy
    cookies.delete(:session_id)
    redirect_to root_path, notice: "Your account has been deleted."
  end
end
