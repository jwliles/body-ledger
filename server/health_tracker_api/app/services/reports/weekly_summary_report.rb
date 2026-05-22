module Reports
  class WeeklySummaryReport < BaseReport
    def call
      week_end = end_date
      week_start = start_date || week_end.beginning_of_week
      previous_start = week_start - 7.days
      previous_end = week_start - 1.day

      this_week = current_events(week_start, week_end).to_a
      last_week = current_events(previous_start, previous_end).to_a

      {
        id: "weekly_summary",
        title: "Weekly Summary",
        explanation: "Compares this week to last week, breaks down daily core metrics, and highlights notable BP and activity records.",
        period: {
          start_date: week_start,
          end_date: week_end,
          previous_start_date: previous_start,
          previous_end_date: previous_end
        },
        sections: [
          weekly_comparison(this_week, last_week),
          daily_breakdown(this_week, week_start, week_end),
          weekly_highlights(this_week)
        ],
        legacy_fields: Reports::LegacyMetricMap.as_json
      }
    end

    private

    def weekly_comparison(this_week, last_week)
      this_metrics = metrics_for(this_week)
      last_metrics = metrics_for(last_week)

      rows = [
        comparison_row("Avg Systolic BP", this_metrics[:avg_sys], last_metrics[:avg_sys]),
        comparison_row("Avg Diastolic BP", this_metrics[:avg_dia], last_metrics[:avg_dia]),
        comparison_row("Avg Pulse", this_metrics[:avg_pulse], last_metrics[:avg_pulse]),
        comparison_row("Weight (Start -> End)", this_metrics[:weight_range], last_metrics[:weight_range], change: this_metrics[:weight_change]),
        comparison_row("Total Steps", this_metrics[:total_steps], last_metrics[:total_steps]),
        comparison_row("Avg Steps/Day", this_metrics[:avg_steps_per_day], last_metrics[:avg_steps_per_day]),
        comparison_row("Avg Sleep (mins)", this_metrics[:avg_sleep_minutes], last_metrics[:avg_sleep_minutes])
      ]

      {
        id: "weekly_comparison",
        title: "Weekly Comparison",
        columns: %w[metric this_week last_week change],
        rows: rows
      }
    end

    def daily_breakdown(events, week_start, week_end)
      rows = (week_start..week_end).map do |date|
        day_events = events.select { |event| event.date_key == date }
        payloads = bp_payloads(day_events)
        weight_payload = events_for(day_events, "weight").max_by(&:recorded_at)&.weight_payload

        {
          day: date.strftime("%A"),
          date: date,
          average_systolic: average(payloads.map(&:systolic)),
          average_diastolic: average(payloads.map(&:diastolic)),
          weight: weight_lb(weight_payload),
          steps: sum_or_nil(events_for(day_events, "activity").map { |event| steps(event.activity_payload) }),
          sleep_minutes: sum_or_nil(events_for(day_events, "sleep").map { |event| sleep_minutes(event.sleep_payload) })
        }
      end

      {
        id: "daily_breakdown",
        title: "Daily Breakdown",
        columns: %w[day date average_systolic average_diastolic weight steps sleep_minutes],
        rows: rows
      }
    end

    def weekly_highlights(events)
      bp_events = events_for(events, "blood_pressure")
      step_events = events_for(events, "activity").select { |event| event.activity_payload&.activity_type == "steps" }

      best_bp = bp_events.min_by { |event| [ event.blood_pressure_payload.systolic, event.blood_pressure_payload.diastolic ] }
      highest_bp = bp_events.max_by { |event| [ event.blood_pressure_payload.systolic, event.blood_pressure_payload.diastolic ] }
      most_active = step_events.max_by { |event| event.activity_payload.steps.to_i }
      least_active = step_events.min_by { |event| event.activity_payload.steps.to_i }

      {
        id: "weekly_highlights",
        title: "Weekly Highlights",
        columns: %w[category value date],
        rows: [
          bp_row("Best BP Reading", best_bp),
          bp_row("Highest BP Reading", highest_bp),
          activity_row("Most Active Day", most_active),
          activity_row("Least Active Day", least_active)
        ]
      }
    end

    def metrics_for(events)
      payloads = bp_payloads(events)
      weights = events_for(events, "weight").sort_by(&:recorded_at).filter_map { |event| weight_lb(event.weight_payload) }
      daily_steps = events_for(events, "activity").group_by(&:date_key).transform_values do |day_events|
        day_events.filter_map { |event| steps(event.activity_payload) }.sum
      end
      sleep_values = events_for(events, "sleep").filter_map { |event| sleep_minutes(event.sleep_payload) }

      {
        avg_sys: average(payloads.map(&:systolic)),
        avg_dia: average(payloads.map(&:diastolic)),
        avg_pulse: average(payloads.map(&:pulse)),
        weight_range: weights.any? ? "#{weights.first} -> #{weights.last} lbs" : nil,
        weight_change: weights.size >= 2 ? (weights.last - weights.first).round(1) : nil,
        total_steps: daily_steps.values.sum,
        avg_steps_per_day: daily_steps.any? ? average(daily_steps.values) : nil,
        avg_sleep_minutes: average(sleep_values, digits: 0)
      }
    end

    def comparison_row(metric, this_week, last_week, change: nil)
      {
        metric: metric,
        this_week: source(this_week, "projected"),
        last_week: source(last_week, "projected"),
        change: source(change || percent_change(this_week, last_week), "derived")
      }
    end

    def bp_row(category, event)
      payload = event&.blood_pressure_payload
      {
        category: category,
        value: payload ? "#{payload.systolic}/#{payload.diastolic}" : nil,
        date: event&.date_key
      }
    end

    def activity_row(category, event)
      {
        category: category,
        value: event&.activity_payload&.steps,
        date: event&.date_key
      }
    end
  end
end
