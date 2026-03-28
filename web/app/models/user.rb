class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :tracks, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  generates_token_for :email_verification, expires_in: 24.hours do
    email_verified_at
  end

  generates_token_for :password_reset, expires_in: 15.minutes do
    password_salt.last(10)
  end

  def email_verified?
    email_verified_at?
  end
end
