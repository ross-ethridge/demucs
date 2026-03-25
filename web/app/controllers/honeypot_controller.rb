class HoneypotController < ApplicationController

  def trap
    redirect_to "http://localhost", allow_other_host: true
  end
end
