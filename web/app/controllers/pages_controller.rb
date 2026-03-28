class PagesController < ApplicationController
  allow_unauthenticated_access only: %i[legal sitemap]

  def home
    redirect_to tracks_path
  end

  def legal
  end

  def sitemap
    expires_in 1.day, public: true
  end
end
