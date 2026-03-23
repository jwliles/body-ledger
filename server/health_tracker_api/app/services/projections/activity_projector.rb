module Projections
  class ActivityProjector < BaseProjector
    def self.metric_type = "activity"

    private

    def compute_summary(events)
      payloads = events.map(&:activity_payload)

      {
        session_count:          payloads.size,
        total_duration_minutes: payloads.sum(&:duration_minutes),
        total_distance_km:      payloads.filter_map(&:distance_km).sum.round(3),
        total_steps:            payloads.filter_map(&:steps).sum,
        total_calories_burned:  payloads.filter_map(&:calories_burned).sum,
        activity_types:         payloads.map(&:activity_type).uniq.sort
      }
    end
  end
end
