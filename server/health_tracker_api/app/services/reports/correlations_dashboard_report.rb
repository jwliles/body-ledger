module Reports
  class CorrelationsDashboardReport < BaseReport
    def call
      range_start = start_date || end_date - 89.days
      events = current_events(range_start, end_date).to_a
      daily = daily_points(events, range_start, end_date)

      {
        id: "correlations_dashboard",
        title: "Correlations Dashboard",
        explanation: "Calculates exploratory Pearson correlations across sleep, BP, steps, and weight. These are descriptive, not medical conclusions.",
        period: {
          start_date: range_start,
          end_date: end_date
        },
        sections: [
          correlation_rows(daily)
        ]
      }
    end

    private

    def daily_points(events, range_start, range_end)
      (range_start..range_end).map do |date|
        day_events = events.select { |event| event.date_key == date }
        bp = bp_payloads(day_events)
        {
          date: date,
          sleep: sum_or_nil(events_for(day_events, "sleep").map { |event| sleep_minutes(event.sleep_payload) }),
          steps: sum_or_nil(events_for(day_events, "activity").map { |event| steps(event.activity_payload) }),
          systolic: average(bp.map(&:systolic)),
          diastolic: average(bp.map(&:diastolic)),
          weight: weight_lb(events_for(day_events, "weight").max_by(&:recorded_at)&.weight_payload)
        }
      end
    end

    def correlation_rows(daily)
      rows = [
        correlation_row("Sleep vs Systolic BP", daily, :sleep, :systolic),
        correlation_row("Sleep vs Diastolic BP", daily, :sleep, :diastolic),
        correlation_row("Sleep vs Steps", daily, :sleep, :steps),
        correlation_row("Steps vs Weight", daily, :steps, :weight)
      ]

      {
        id: "correlations",
        title: "Correlations",
        columns: %w[metric coefficient strength direction n],
        rows: rows
      }
    end

    def correlation_row(metric, daily, left, right)
      pairs = daily.filter_map do |point|
        x = point[left]
        y = point[right]
        x.nil? || y.nil? ? nil : [ x.to_f, y.to_f ]
      end
      r = pearson(pairs)

      {
        metric: metric,
        coefficient: r,
        strength: strength_label(r),
        direction: r.nil? ? nil : (r.positive? ? "positive" : "negative"),
        n: pairs.size
      }
    end

    def pearson(pairs)
      return nil if pairs.size < 2

      xs = pairs.map(&:first)
      ys = pairs.map(&:last)
      x_avg = average(xs, digits: 6)
      y_avg = average(ys, digits: 6)
      numerator = pairs.sum { |x, y| (x - x_avg) * (y - y_avg) }
      x_den = Math.sqrt(xs.sum { |x| (x - x_avg)**2 })
      y_den = Math.sqrt(ys.sum { |y| (y - y_avg)**2 })
      return nil if x_den.zero? || y_den.zero?

      (numerator / (x_den * y_den)).round(3)
    end

    def strength_label(value)
      return nil if value.nil?

      absolute = value.abs
      return "strong" if absolute >= 0.7
      return "moderate" if absolute >= 0.3

      "weak"
    end
  end
end
