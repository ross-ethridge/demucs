class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user

  private

  def current_user
    @current_user ||= User.first_or_create!(
      email_address:     "local@localhost",
      password:          SecureRandom.hex(16),
      email_verified_at: Time.current
    )
  end
end
