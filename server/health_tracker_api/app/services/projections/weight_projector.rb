module Projections
  class WeightProjector < BaseProjector
    def self.metric_type = "weight"

    private

    def compute_summary(events)
      values_kg = events.map { |e| e.weight_payload.value_kg.to_f }

      {
        count:     values_kg.size,
        value_kg:  values_kg.last,     # most recent reading of the day
        avg_kg:    avg(values_kg),
        min_kg:    values_kg.min,
        max_kg:    values_kg.max
      }
    end

    def avg(values)
      return nil if values.empty?
      (values.sum / values.size).round(3)
    end
  end
end
