module Projections
  class BloodPressureProjector < BaseProjector
    def self.metric_type = "blood_pressure"

    # All BP aggregates split by reading_context (wake / sleep).
    # Queries without a reading_context filter are forbidden — this enforces it.
    def project!
      %w[wake sleep].each do |ctx|
        events = current_events.joins(:blood_pressure_payload)
                               .where(blood_pressure_payloads: { reading_context: ctx })
        next unless events.any?

        summary = compute_summary_for_context(events)

        DailySummary.upsert(
          {
            user_id:      user.id,
            summary_date: date,
            metric_type:  "blood_pressure_#{ctx}",
            summary_data: summary,
            status:       "confirmed",
            created_at:   Time.current,
            updated_at:   Time.current
          },
          unique_by: %i[user_id summary_date metric_type],
          update_only: %i[summary_data status updated_at]
        )
      end
    end

    private

    def compute_summary_for_context(events)
      payloads = events.map(&:blood_pressure_payload)
      systolics  = payloads.map(&:systolic)
      diastolics = payloads.map(&:diastolic)
      pulses     = payloads.filter_map(&:pulse)

      {
        count:           payloads.size,
        systolic_avg:    avg(systolics),
        systolic_min:    systolics.min,
        systolic_max:    systolics.max,
        diastolic_avg:   avg(diastolics),
        diastolic_min:   diastolics.min,
        diastolic_max:   diastolics.max,
        pulse_avg:       pulses.any? ? avg(pulses) : nil
      }
    end

    def avg(values)
      return nil if values.empty?
      (values.sum.to_f / values.size).round(1)
    end

    def compute_summary(_events)
      # Not used — project! is overridden to split by context.
      raise "Use project! directly"
    end
  end
end
