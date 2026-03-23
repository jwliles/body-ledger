class SymptomPayload < ApplicationRecord
  include ImmutableRecord

  self.primary_key = :health_event_id

  belongs_to :health_event

  validates :symptom_code, presence: true
  validates :severity,     presence: true,
    numericality: { only_integer: true, in: 1..10 }
end
