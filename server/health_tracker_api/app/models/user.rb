class User < ApplicationRecord
  has_many :devices, dependent: :destroy
  has_many :health_events
  has_many :medications
  has_many :daily_summaries

  validates :email, presence: true, uniqueness: true

  # Verifies a plain-text password against the bcrypt-hashed encrypted_password
  # column (Devise convention, but usable without Devise at the model level).
  def authenticate(password)
    return false if encrypted_password.blank?
    BCrypt::Password.new(encrypted_password).is_password?(password)
  end
end
