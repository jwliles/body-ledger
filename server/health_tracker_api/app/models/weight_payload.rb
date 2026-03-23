class WeightPayload < ApplicationRecord
  include ImmutableRecord

  self.primary_key = :health_event_id

  belongs_to :health_event

  UNITS = %w[kg lb st].freeze

  validates :value_kg,       presence: true,
    numericality: { greater_than: 0, less_than: 700 }
  validates :original_unit,  inclusion: { in: UNITS }, allow_nil: true
  validates :original_value, numericality: { greater_than: 0 }, allow_nil: true
end
