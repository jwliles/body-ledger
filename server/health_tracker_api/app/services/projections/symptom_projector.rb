module Projections
  class SymptomProjector < BaseProjector
    def self.metric_type = "symptom"

    private

    def compute_summary(events)
      payloads = events.map(&:symptom_payload)

      by_symptom = payloads.group_by(&:symptom_code).transform_values do |group|
        severities = group.map(&:severity)
        {
          count:        group.size,
          severity_avg: (severities.sum.to_f / severities.size).round(1),
          severity_max: severities.max,
          locations:    group.filter_map(&:body_location).uniq
        }
      end

      {
        total_count: payloads.size,
        by_symptom:  by_symptom
      }
    end
  end
end
