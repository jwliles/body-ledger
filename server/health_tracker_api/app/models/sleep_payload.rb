class SleepPayload < ApplicationRecord
  include ImmutableRecord

  self.primary_key = :health_event_id

  belongs_to :health_event

  validates :sleep_start, presence: true
  validates :sleep_end,   presence: true
  validate  :end_after_start

  private

  def end_after_start
    return unless sleep_start && sleep_end
    errors.add(:sleep_end, "must be after sleep_start") if sleep_end <= sleep_start
  end
end
