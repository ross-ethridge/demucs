class HoneypotController < ApplicationController
  skip_before_action :require_authentication, raise: false

  def trap
    redirect_to "https://youtu.be/yvqVg7jsQC4?si=m_y9vPUQljF3XbMz", allow_other_host: true
  end
end
