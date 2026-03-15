class PagesController < ApplicationController
  skip_before_action :require_authentication

  def legal
  end
end
