class PagesController < ApplicationController
  skip_before_action :require_authentication

  def home
    redirect_to tracks_path if authenticated?
  end

  def legal
  end

  def sitemap
    expires_in 1.day, public: true
  end
end
