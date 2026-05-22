module Reports
  class TrendsDashboardReport < BaseReport
    def call
      range_start = start_date || end_date - 89.days
      events = current_events(range_start, end_date).to_a

      {
        id: "trends_dashboard",
        title: "Trends Dashboard",
        explanation: "Trend summaries for BP, pulse, weight, steps, and sleep efficiency over the selected period.",
        period: {
          start_date: range_start,
          end_date: end_date
        },
        sections: [
          trend_summary(events),
          sleep_efficiency_summary(events),
          daily_trends(events, range_start, end_date)
        ]
      }
    end

    private

    def trend_summary(events)
      bp = bp_payloads(events)
      weights = events_for(events, "weight").sort_by(&:recorded_at).filter_map { |event| weight_lb(event.weight_payload) }
      steps_values = events_for(events, "activity").filter_map { |event| steps(event.activity_payload) }

      {
        id: "trend_summary",
        title: "Trend Summary",
        columns: %w[metric value],
        rows: [
          { metric: "Avg Systolic BP", value: average(bp.map(&:systolic)) },
          { metric: "Avg Diastolic BP", value: average(bp.map(&:diastolic)) },
          { metric: "Avg Pulse", value: average(bp.map(&:pulse)) },
          { metric: "Weight Change", value: weights.size >= 2 ? (weights.last - weights.first).round(1) : nil },
          { metric: "Avg Steps", value: average(steps_values, digits: 0) }
        ]
      }
    end

    def sleep_efficiency_summary(events)
      values = events_for(events, "sleep").filter_map { |event| event.sleep_payload.sleep_efficiency_percent }

      {
        id: "sleep_efficiency",
        title: "Sleep Efficiency",
        columns: %w[metric average min max],
        rows: [
          {
            metric: "Sleep Efficiency",
            average: average(values),
            min: values.min,
            max: values.max
          }
        ]
      }
    end

    def daily_trends(events, range_start, range_end)
      rows = (range_start..range_end).map do |date|
        day_events = events.select { |event| event.date_key == date }
        bp = bp_payloads(day_events)
        {
          date: date,
          avg_systolic: average(bp.map(&:systolic)),
          avg_diastolic: average(bp.map(&:diastolic)),
          weight: weight_lb(events_for(day_events, "weight").max_by(&:recorded_at)&.weight_payload),
          steps: sum_or_nil(events_for(day_events, "activity").map { |event| steps(event.activity_payload) }),
          sleep_efficiency: average(events_for(day_events, "sleep").filter_map { |event| event.sleep_payload.sleep_efficiency_percent })
        }
      end

      {
        id: "daily_trends",
        title: "Daily Trends",
        columns: %w[date avg_systolic avg_diastolic weight steps sleep_efficiency],
        rows: rows
      }
    end
  end
end
