class ActivityPayload < ApplicationRecord
  include ImmutableRecord

  self.primary_key = :health_event_id

  belongs_to :health_event

  validates :activity_type,    presence: true
  validates :duration_minutes, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :distance_km,      numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :steps,            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :heart_rate_avg,   numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :calories_burned,  numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
end
