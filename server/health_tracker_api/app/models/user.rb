class User < ApplicationRecord
  attr_accessor :password

  has_many :devices, dependent: :destroy
  has_many :health_events
  has_many :medications
  has_many :daily_summaries

  USERNAME_FORMAT = /\A[a-zA-Z0-9][a-zA-Z0-9_-]*\z/

  validates :username,           presence: true, uniqueness: true,
                                 format: { with: USERNAME_FORMAT,
                                           message: "may only contain letters, digits, underscores, and hyphens, and must start with a letter or digit" }
  validates :email,              format: { with: URI::MailTo::EMAIL_REGEXP },
                                 uniqueness: { allow_blank: true },
                                 allow_blank: true
  validates :encrypted_password, presence: true
  validates :time_zone,          presence: true
  validates :password,           password_complexity: true, if: -> { @password.present? }

  def password=(plain)
    @password = plain
    self.encrypted_password = BCrypt::Password.create(plain) if plain.present?
  end

  def authenticate(plain)
    return false if encrypted_password.blank?
    BCrypt::Password.new(encrypted_password).is_password?(plain)
  end

  def generate_otp_secret!
    self.otp_secret = ROTP::Base32.random
    save!
  end

  def validate_otp!(code)
    return false if otp_secret.blank?
    totp       = ROTP::TOTP.new(otp_secret, issuer: "BodyLedger")
    after_time = consumed_timestep ? Time.at(consumed_timestep) : nil
    timestamp  = totp.verify(code, drift_behind: 15, drift_ahead: 15, after: after_time)
    return false unless timestamp
    update_column(:consumed_timestep, timestamp)
    true
  end

  def otp_provisioning_uri
    ROTP::TOTP.new(otp_secret, issuer: "BodyLedger").provisioning_uri(username)
  end
end
