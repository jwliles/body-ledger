class SleepPayload < ApplicationRecord
  include ImmutableRecord

  self.primary_key = :health_event_id

  belongs_to :health_event

  validates :sleep_start, presence: true
  validates :sleep_end,   presence: true
  validates :sleep_minutes, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate  :end_after_start

  def time_in_bed_minutes
    duration_minutes
  end

  def reported_sleep_minutes
    sleep_minutes || duration_minutes
  end

  def sleep_efficiency_percent
    return nil unless reported_sleep_minutes && time_in_bed_minutes&.positive?

    ((reported_sleep_minutes.to_f / time_in_bed_minutes) * 100).round(1)
  end

  private

  def end_after_start
    return unless sleep_start && sleep_end
    errors.add(:sleep_end, "must be after sleep_start") if sleep_end <= sleep_start
  end
end
