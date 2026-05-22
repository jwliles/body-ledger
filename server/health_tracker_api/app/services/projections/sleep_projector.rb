module Projections
  class SleepProjector < BaseProjector
    def self.metric_type = "sleep"

    private

    def compute_summary(events)
      # date_key is the wake date, so a given day may have one sleep record.
      # If multiple somehow exist (amendments edge case), sum durations.
      payloads     = events.map(&:sleep_payload)
      time_in_bed  = payloads.filter_map(&:time_in_bed_minutes).sum
      sleep_min    = payloads.filter_map(&:reported_sleep_minutes).sum
      sleep_starts = payloads.map(&:sleep_start)
      sleep_ends   = payloads.map(&:sleep_end)
      efficiency   = time_in_bed.positive? ? ((sleep_min.to_f / time_in_bed) * 100).round(1) : nil

      {
        sleep_minutes:            sleep_min,
        time_in_bed_minutes:      time_in_bed,
        awake_minutes:            [ time_in_bed - sleep_min, 0 ].max,
        sleep_efficiency_percent: efficiency,
        sleep_start:              sleep_starts.min&.iso8601,
        sleep_end:                sleep_ends.max&.iso8601,
        session_count:            payloads.size,
        provenance: {
          sleep_minutes: payloads.any?(&:sleep_minutes) ? "entered" : "derived_from_interval",
          time_in_bed_minutes: "derived_from_sleep_start_and_sleep_end",
          sleep_efficiency_percent: "derived_from_sleep_minutes_and_time_in_bed"
        }
      }
    end
  end
end
