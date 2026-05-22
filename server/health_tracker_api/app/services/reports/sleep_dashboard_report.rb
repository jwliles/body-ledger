module Reports
  class SleepDashboardReport < BaseReport
    def call
      range_start = start_date || end_date - 29.days
      events = current_events(range_start, end_date).to_a
      rows = sleep_rows(events)
      efficiencies = rows.filter_map { |row| row[:sleep_efficiency_percent][:value] }

      {
        id: "sleep_dashboard",
        title: "Sleep Dashboard",
        explanation: "Tracks bedtime, wake time, tracker sleep minutes, time in bed, and derived sleep efficiency. Cross-day joins belong to report projections, not raw records.",
        period: {
          start_date: range_start,
          end_date: end_date
        },
        sections: [
          {
            id: "sleep_efficiency",
            title: "Sleep Efficiency",
            columns: %w[date bedtime wake_time sleep_minutes time_in_bed_minutes awake_minutes sleep_efficiency_percent],
            rows: rows
          },
          {
            id: "sleep_efficiency_summary",
            title: "Sleep Efficiency Summary",
            columns: %w[metric average min max status],
            rows: [
              {
                metric: "Sleep Efficiency",
                average: source(average(efficiencies), "derived"),
                min: source(efficiencies.min, "derived"),
                max: source(efficiencies.max, "derived"),
                status: efficiency_status(average(efficiencies))
              }
            ]
          }
        ],
        legacy_fields: Reports::LegacyMetricMap.as_json.slice("bedtime", "wake_time", "sleep", "sleep_mins", "qty", "med", "med_type")
      }
    end

    private

    def sleep_rows(events)
      events_for(events, "sleep").sort_by(&:date_key).map do |event|
        payload = event.sleep_payload
        time_in_bed = payload.time_in_bed_minutes
        sleep_min = payload.reported_sleep_minutes
        awake = [ time_in_bed.to_i - sleep_min.to_i, 0 ].max

        {
          date: event.date_key,
          bedtime: source(payload.sleep_start&.iso8601, "entered"),
          wake_time: source(payload.sleep_end&.iso8601, "entered"),
          sleep_minutes: source(sleep_min, payload.sleep_minutes ? "entered" : "derived_from_interval"),
          time_in_bed_minutes: source(time_in_bed, "derived_from_bedtime_and_wake_time"),
          awake_minutes: source(awake, "derived_from_time_in_bed_minus_sleep"),
          sleep_efficiency_percent: source(payload.sleep_efficiency_percent, "derived_from_sleep_minutes_and_time_in_bed")
        }
      end
    end

    def efficiency_status(value)
      return "unknown" if value.nil?
      return "good" if value >= 85
      return "fair" if value >= 75

      "poor"
    end
  end
end
