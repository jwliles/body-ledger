class Medication < ApplicationRecord
  belongs_to :user
  has_many :medication_dose_payloads

  before_validation :derive_strength

  validates :name,      presence: true
  validates :strength,  presence: true
  validates :med_form,  presence: true
  validates :dosage,    presence: true, numericality: { greater_than: 0 }
  validates :dose_unit, presence: true
  validates :pill_size_mg, presence: true, numericality: { greater_than: 0 }
  validates :rx_qty, numericality: { greater_than: 0 }, allow_nil: true
  validates :rx_per_day, numericality: { greater_than: 0 }, allow_nil: true

  # Scheduled medications must have scheduled_times set.
  validate :scheduled_times_present_when_not_prn

  private

  def derive_strength
    return if strength.present?
    return if pill_size_mg.blank? || dose_unit.blank? || med_form.blank?

    self.strength = "#{pill_size_mg.to_fs(:delimited)}#{dose_unit} #{med_form}"
  end

  def scheduled_times_present_when_not_prn
    return if is_prn?
    errors.add(:scheduled_times, "must be set for scheduled medications") if scheduled_times.blank?
  end
end
