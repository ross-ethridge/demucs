class HoneypotController < ApplicationController
  skip_before_action :require_authentication, raise: false

  def trap
    redirect_to "https://www.youtube.com/watch?v=dQw4w9WgXcQ", allow_other_host: true
  end
end
