class SleepPayload < ApplicationRecord
  include ImmutableRecord

  self.primary_key = :health_event_id

  belongs_to :health_event

  validates :sleep_minutes, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate  :minutes_or_interval_present
  validate  :end_after_start

  def time_in_bed_minutes
    duration_minutes
  end

  def reported_sleep_minutes
    sleep_minutes || time_in_bed_minutes
  end

  def sleep_efficiency_percent
    return nil unless reported_sleep_minutes && time_in_bed_minutes&.positive?

    ((reported_sleep_minutes.to_f / time_in_bed_minutes) * 100).round(1)
  end

  private

  def minutes_or_interval_present
    return if sleep_minutes.present?
    return if sleep_start.present? && sleep_end.present?

    errors.add(:base, "must include sleep minutes or a sleep interval")
  end

  def end_after_start
    return if sleep_start.blank? || sleep_end.blank?
    errors.add(:sleep_end, "must be after sleep_start") if sleep_end <= sleep_start
  end
end
