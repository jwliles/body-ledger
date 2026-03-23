class Medication < ApplicationRecord
  include ImmutableRecord

  belongs_to :user
  has_many :medication_dose_payloads

  validates :name,     presence: true
  validates :strength, presence: true

  # Scheduled medications must have scheduled_times set.
  validate :scheduled_times_present_when_not_prn

  private

  def scheduled_times_present_when_not_prn
    return if is_prn?
    errors.add(:scheduled_times, "must be set for scheduled medications") if scheduled_times.blank?
  end
end
