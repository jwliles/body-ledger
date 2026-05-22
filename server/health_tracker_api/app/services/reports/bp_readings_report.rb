module Reports
  class BpReadingsReport < BaseReport
    def call
      range_start = start_date || end_date - 29.days
      events = current_events(range_start, end_date).to_a

      {
        id: "bp_readings",
        title: "BP Readings",
        explanation: "Lists BP readings and nearest same-day medication dose timing for the selected period.",
        period: {
          start_date: range_start,
          end_date: end_date
        },
        sections: [
          bp_readings(events)
        ]
      }
    end

    private

    def bp_readings(events)
      dose_events = events_for(events, "medication_dose")
      rows = events_for(events, "blood_pressure").sort_by(&:recorded_at).map do |event|
        payload = event.blood_pressure_payload
        nearest = nearest_dose(event, dose_events)
        {
          date: event.date_key,
          bp_time: event.recorded_at.iso8601,
          context: payload.reading_context,
          systolic: payload.systolic,
          diastolic: payload.diastolic,
          pulse: payload.pulse,
          nearest_med_time: nearest&.recorded_at&.iso8601,
          delta_minutes: nearest ? ((event.recorded_at - nearest.recorded_at) / 60).round : nil
        }
      end

      {
        id: "bp_reading_rows",
        title: "BP Readings",
        columns: %w[date bp_time context systolic diastolic pulse nearest_med_time delta_minutes],
        rows: rows
      }
    end

    def nearest_dose(event, dose_events)
      dose_events
        .select { |dose| dose.date_key == event.date_key }
        .min_by { |dose| (event.recorded_at - dose.recorded_at).abs }
    end
  end
end
