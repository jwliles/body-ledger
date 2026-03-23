class DailySummary < ApplicationRecord
  belongs_to :user

  METRIC_TYPES   = HealthEvent::METRIC_TYPES +
                   %w[blood_pressure_wake blood_pressure_sleep]
  STATUSES       = %w[projected confirmed stale].freeze

  validates :summary_date, presence: true
  validates :metric_type,  inclusion: { in: METRIC_TYPES }
  validates :status,       inclusion: { in: STATUSES }

  scope :stale,     -> { where(status: "stale") }
  scope :confirmed, -> { where(status: "confirmed") }
end
