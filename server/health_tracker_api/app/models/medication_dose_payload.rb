class MedicationDosePayload < ApplicationRecord
  include ImmutableRecord

  self.primary_key = :health_event_id

  belongs_to :health_event
  belongs_to :medication

  DOSE_TYPES = %w[scheduled prn missed reconciliation].freeze

  validates :dose_mg,   presence: true, numericality: { greater_than: 0 }
  validates :dose_type, inclusion: { in: DOSE_TYPES }

  # PRN medications can never have a 'missed' dose — they're taken as-needed.
  validate :prn_cannot_be_missed

  private

  def prn_cannot_be_missed
    return unless dose_type == "missed" && medication&.is_prn?
    errors.add(:dose_type, "cannot be 'missed' for a PRN medication")
  end
end
