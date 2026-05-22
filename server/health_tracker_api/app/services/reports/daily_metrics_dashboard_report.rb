module Reports
  class DailyMetricsDashboardReport < BaseReport
    def call
      range_start = start_date || end_date - 29.days
      events = current_events(range_start, end_date).to_a

      {
        id: "daily_metrics_dashboard",
        title: "Daily Metrics Dashboard",
        explanation: "Daily snapshot of BP, medication timing, activity, weight, and sleep-related metrics.",
        period: {
          start_date: range_start,
          end_date: end_date
        },
        sections: [
          daily_rows(events, range_start, end_date),
          sleep_rows(events),
          bp_rows(events)
        ]
      }
    end

    private

    def daily_rows(events, range_start, range_end)
      rows = (range_start..range_end).map do |date|
        day_events = events.select { |event| event.date_key == date }
        bp = bp_payloads(day_events)
        weight = events_for(day_events, "weight").max_by(&:recorded_at)&.weight_payload

        {
          date: date,
          wake_systolic: context_bp(day_events, "wake")&.systolic,
          wake_diastolic: context_bp(day_events, "wake")&.diastolic,
          sleep_systolic: context_bp(day_events, "sleep")&.systolic,
          sleep_diastolic: context_bp(day_events, "sleep")&.diastolic,
          average_pulse: average(bp.map(&:pulse)),
          weight: weight_lb(weight),
          steps: sum_or_nil(events_for(day_events, "activity").map { |event| steps(event.activity_payload) }),
          sleep_minutes: sum_or_nil(events_for(day_events, "sleep").map { |event| sleep_minutes(event.sleep_payload) })
        }
      end

      {
        id: "daily_metrics",
        title: "Daily Metrics",
        columns: %w[date wake_systolic wake_diastolic sleep_systolic sleep_diastolic average_pulse weight steps sleep_minutes],
        rows: rows
      }
    end

    def sleep_rows(events)
      rows = events_for(events, "sleep").sort_by(&:date_key).map do |event|
        payload = event.sleep_payload
        {
          date: event.date_key,
          bedtime: payload.sleep_start&.iso8601,
          wake_time: payload.sleep_end&.iso8601,
          sleep_minutes: payload.reported_sleep_minutes,
          time_in_bed_minutes: payload.time_in_bed_minutes,
          sleep_efficiency_percent: payload.sleep_efficiency_percent
        }
      end

      {
        id: "sleep_metrics",
        title: "Sleep Metrics",
        columns: %w[date bedtime wake_time sleep_minutes time_in_bed_minutes sleep_efficiency_percent],
        rows: rows
      }
    end

    def bp_rows(events)
      rows = events_for(events, "blood_pressure").sort_by(&:recorded_at).map do |event|
        payload = event.blood_pressure_payload
        {
          date: event.date_key,
          time: event.recorded_at.iso8601,
          context: payload.reading_context,
          systolic: payload.systolic,
          diastolic: payload.diastolic,
          pulse: payload.pulse
        }
      end

      {
        id: "bp_readings",
        title: "BP Readings",
        columns: %w[date time context systolic diastolic pulse],
        rows: rows
      }
    end

    def context_bp(events, context)
      events_for(events, "blood_pressure")
        .map(&:blood_pressure_payload)
        .find { |payload| payload.reading_context == context }
    end
  end
end
