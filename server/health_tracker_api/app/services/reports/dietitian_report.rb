module Reports
  class DietitianReport < BaseReport
    def call
      range_start = start_date || end_date - 83.days
      events = current_events(range_start, end_date).to_a

      {
        id: "dietitian_report",
        title: "Dietitian Report",
        explanation: "Summarizes weight, activity, BP, and sleep over a 12-week reporting window for clinician review.",
        period: {
          start_date: range_start,
          end_date: end_date
        },
        sections: [
          summary(events, range_start, end_date),
          weekly_weight_activity(events, range_start, end_date),
          weekly_health_indicators(events, range_start, end_date)
        ]
      }
    end

    private

    def summary(events, range_start, range_end)
      weights = events_for(events, "weight").sort_by(&:recorded_at).filter_map { |event| weight_lb(event.weight_payload) }
      weeks = ((range_end - range_start).to_i + 1) / 7.0
      change = weights.size >= 2 ? (weights.last - weights.first).round(1) : nil

      {
        id: "twelve_week_summary",
        title: "12-Week Summary",
        columns: %w[metric value],
        rows: [
          { metric: "Time Period", value: "#{weeks.round(1)} weeks" },
          { metric: "Starting Weight", value: weights.first },
          { metric: "Current Weight", value: weights.last },
          { metric: "Total Change", value: change },
          { metric: "Average Rate", value: change ? (change / weeks).round(2) : nil },
          { metric: "Goal Rate", value: "1.25 lbs/week" }
        ]
      }
    end

    def weekly_weight_activity(events, range_start, range_end)
      rows = week_ranges(range_start, range_end).map do |week_start, week_end|
        week_events = events.select { |event| event.date_key.between?(week_start, week_end) }
        weights = events_for(week_events, "weight").sort_by(&:recorded_at).filter_map { |event| weight_lb(event.weight_payload) }
        steps_by_day = events_for(week_events, "activity").group_by(&:date_key).transform_values do |day_events|
          day_events.filter_map { |event| steps(event.activity_payload) }.sum
        end
        change = weights.size >= 2 ? (weights.last - weights.first).round(1) : nil

        {
          week_ending: week_end,
          weight_start: weights.first,
          weight_end: weights.last,
          change: change,
          avg_steps_per_day: steps_by_day.any? ? average(steps_by_day.values, digits: 0) : nil,
          days: (week_end - week_start).to_i + 1
        }
      end

      {
        id: "weekly_weight_activity",
        title: "Weekly Weight & Activity Trends",
        columns: %w[week_ending weight_start weight_end change avg_steps_per_day days],
        rows: rows
      }
    end

    def weekly_health_indicators(events, range_start, range_end)
      rows = week_ranges(range_start, range_end).map do |week_start, week_end|
        week_events = events.select { |event| event.date_key.between?(week_start, week_end) }
        payloads = bp_payloads(week_events)
        steps_total = events_for(week_events, "activity").filter_map { |event| steps(event.activity_payload) }.sum
        sleep_values = events_for(week_events, "sleep").filter_map { |event| sleep_minutes(event.sleep_payload) }

        {
          week_ending: week_end,
          avg_steps_per_day: average_daily_steps(week_events),
          total_steps: steps_total,
          avg_systolic: average(payloads.map(&:systolic)),
          avg_diastolic: average(payloads.map(&:diastolic)),
          avg_map: average(payloads.map { |p| p.diastolic + ((p.systolic - p.diastolic) / 3.0) }),
          avg_sleep_min: average(sleep_values, digits: 0)
        }
      end

      {
        id: "weekly_health_indicators",
        title: "Weekly Health Indicators",
        columns: %w[week_ending avg_steps_per_day total_steps avg_systolic avg_diastolic avg_map avg_sleep_min],
        rows: rows
      }
    end

    def week_ranges(range_start, range_end)
      ranges = []
      cursor = range_start.beginning_of_week
      while cursor <= range_end
        ranges << [ cursor, [ cursor + 6.days, range_end ].min ]
        cursor += 7.days
      end
      ranges
    end

    def average_daily_steps(events)
      steps_by_day = events_for(events, "activity").group_by(&:date_key).transform_values do |day_events|
        day_events.filter_map { |event| steps(event.activity_payload) }.sum
      end
      steps_by_day.any? ? average(steps_by_day.values, digits: 0) : nil
    end
  end
end
