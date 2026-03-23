class BloodPressurePayload < ApplicationRecord
  include ImmutableRecord

  self.primary_key = :health_event_id

  belongs_to :health_event

  READING_CONTEXTS = %w[wake sleep].freeze

  validates :systolic,       presence: true, numericality: { only_integer: true, in: 40..300 }
  validates :diastolic,      presence: true, numericality: { only_integer: true, in: 20..200 }
  validates :pulse,          numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :reading_context, inclusion: { in: READING_CONTEXTS }
end
