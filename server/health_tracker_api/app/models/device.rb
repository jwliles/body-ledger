class Device < ApplicationRecord
  include ImmutableRecord

  belongs_to :user
  has_many :health_events
  has_many :sync_cursors
  has_many :sync_logs

  # Token digest is bcrypt — never store raw token.
  validates :name,         presence: true
  validates :platform,     presence: true,
    inclusion: { in: %w[android ios desktop web] }
  validates :token_digest, presence: true, uniqueness: true

  def self.mutable_columns
    %i[last_seen_at is_active]
  end
end
