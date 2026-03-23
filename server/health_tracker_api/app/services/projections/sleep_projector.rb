module Projections
  class SleepProjector < BaseProjector
    def self.metric_type = "sleep"

    private

    def compute_summary(events)
      # date_key is the wake date, so a given day may have one sleep record.
      # If multiple somehow exist (amendments edge case), sum durations.
      payloads     = events.map(&:sleep_payload)
      total_min    = payloads.sum(&:duration_minutes)
      sleep_starts = payloads.map(&:sleep_start)
      sleep_ends   = payloads.map(&:sleep_end)

      {
        total_duration_minutes: total_min,
        sleep_start:            sleep_starts.min&.iso8601,
        sleep_end:              sleep_ends.max&.iso8601,
        session_count:          payloads.size
      }
    end
  end
end
