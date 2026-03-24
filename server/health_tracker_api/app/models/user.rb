class User < ApplicationRecord
  has_many :devices, dependent: :destroy
  has_many :health_events
  has_many :medications
  has_many :daily_summaries

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :encrypted_password, presence: true
  validates :time_zone, presence: true

  def password=(plain)
    self.encrypted_password = BCrypt::Password.create(plain)
  end

  # Verifies a plain-text password against the bcrypt-hashed encrypted_password column.
  def authenticate(password)
    return false if encrypted_password.blank?
    BCrypt::Password.new(encrypted_password).is_password?(password)
  end

  def generate_otp_secret!
    self.otp_secret = ROTP::Base32.random
    save!
  end

  def validate_otp!(code)
    return false if otp_secret.blank?
    totp = ROTP::TOTP.new(otp_secret, issuer: "BodyLedger")
    after_time = consumed_timestep ? Time.at(consumed_timestep) : nil
    timestamp  = totp.verify(code, drift_behind: 15, drift_ahead: 15, after: after_time)
    return false unless timestamp
    update_column(:consumed_timestep, timestamp)
    true
  end

  def otp_provisioning_uri
    ROTP::TOTP.new(otp_secret, issuer: "BodyLedger").provisioning_uri(email)
  end
end
