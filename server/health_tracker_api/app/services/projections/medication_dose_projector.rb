module Projections
  class MedicationDoseProjector < BaseProjector
    def self.metric_type = "medication_dose"

    private

    def compute_summary(events)
      payloads = events.map(&:medication_dose_payload)

      by_medication = payloads.group_by(&:medication_id).transform_values do |group|
        {
          medication_name: group.first.medication.name,
          total_dose_mg:   group.sum { |p| p.dose_mg.to_f }.round(3),
          dose_types:      group.map(&:dose_type).tally,
          dose_count:      group.size
        }
      end

      {
        total_doses:   payloads.size,
        missed_count:  payloads.count { |p| p.dose_type == "missed" },
        by_medication: by_medication
      }
    end
  end
end
