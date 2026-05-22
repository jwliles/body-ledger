module Reports
  class BaseReport
    attr_reader :user, :start_date, :end_date

    def initialize(user:, start_date: nil, end_date: nil)
      @user = user
      @end_date = cast_date(end_date) || Date.current
      @start_date = cast_date(start_date)
    end

    private

    def cast_date(value)
      return value if value.is_a?(Date)
      return nil if value.blank?

      Date.parse(value.to_s)
    end

    def current_events(range_start, range_end)
      user.health_events
          .current
          .confirmed
          .where(date_key: range_start..range_end)
          .includes(
            :blood_pressure_payload,
            :weight_payload,
            :sleep_payload,
            :activity_payload,
            :medication_dose_payload
          )
    end

    def events_for(events, metric_type, date = nil)
      scoped = events.select { |event| event.metric_type == metric_type }
      date ? scoped.select { |event| event.date_key == date } : scoped
    end

    def average(values, digits: 1)
      values = values.compact.map(&:to_f)
      return nil if values.empty?

      (values.sum / values.size).round(digits)
    end

    def percent_change(current, previous)
      return nil if current.nil? || previous.nil? || previous.to_f.zero?

      (((current.to_f - previous.to_f) / previous.to_f) * 100).round(1)
    end

    def sum_or_nil(values)
      values = values.compact
      return nil if values.empty?

      values.sum
    end

    def weight_lb(payload)
      return nil unless payload
      return payload.original_value.to_f if payload.original_unit == "lb" && payload.original_value

      (payload.value_kg.to_f * 2.2046226218).round(1)
    end

    def bp_payloads(events)
      events.filter_map(&:blood_pressure_payload)
    end

    def sleep_minutes(payload)
      payload&.reported_sleep_minutes
    end

    def steps(payload)
      return nil unless payload&.activity_type == "steps"

      payload.steps
    end

    def source(value, source)
      {
        value: value,
        source: value.nil? ? "unknown" : source
      }
    end
  end
end
