module Reports
  class SleepDashboardReport < BaseReport
    def call
      range_start = start_date || end_date - 29.days
      events = current_events(range_start, end_date).to_a
      rows = sleep_rows(events)
      efficiencies = rows.filter_map { |row| row[:sleep_efficiency_percent][:value] }
      medication_rows = medication_effect_rows(events, group_by: :medication)
      medication_type_rows = medication_effect_rows(events, group_by: :medication_type)

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
            id: "by_medication",
            title: "By Medication",
            columns: %w[label avg_sleep avg_qty avg_systolic avg_diastolic avg_steps nights bp_reads],
            rows: medication_rows
          },
          {
            id: "by_medication_type",
            title: "By Medication Type",
            columns: %w[label avg_sleep avg_qty avg_systolic avg_diastolic avg_steps nights bp_reads],
            rows: medication_type_rows
          },
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

    def medication_effect_rows(events, group_by:)
      buckets = Hash.new do |hash, key|
        hash[key] = {
          sleep: [],
          qty: [],
          sys: [],
          dia: [],
          steps: [],
          nights: 0
        }
      end
      events_by_date = events.group_by(&:date_key)

      sleep_dose_events(events).each do |dose_event|
        payload = dose_event.medication_dose_payload
        medication = payload.medication
        label = group_label(medication, group_by)
        next if label.blank?

        next_date = dose_event.date_key + 1.day
        next_events = events_by_date[next_date] || []
        today_events = events_by_date[dose_event.date_key] || []
        bucket = buckets[label]
        bucket[:nights] += 1

        bucket[:sleep].concat(next_events.filter_map { |event| sleep_minutes(event.sleep_payload) if event.metric_type == "sleep" })
        bucket[:qty] << quantity_taken(payload, medication)
        bucket[:steps].concat(next_events.filter_map { |event| steps(event.activity_payload) if event.metric_type == "activity" })
        add_bp_to_bucket(bucket, today_events, "sleep")
        add_bp_to_bucket(bucket, next_events, "wake")
      end

      buckets.map do |label, bucket|
        {
          label: label,
          avg_sleep: average(bucket[:sleep]),
          avg_qty: average(bucket[:qty]),
          avg_systolic: average(bucket[:sys], digits: 0),
          avg_diastolic: average(bucket[:dia], digits: 0),
          avg_steps: average(bucket[:steps], digits: 0),
          nights: bucket[:nights],
          bp_reads: [ bucket[:sys].size, bucket[:dia].size ].min
        }
      end.sort_by { |row| [ -(row[:avg_sleep] || -1), row[:label].to_s ] }
    end

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

    def sleep_dose_events(events)
      events_for(events, "medication_dose").select do |event|
        event.medication_dose_payload&.timing_context == "sleep"
      end
    end

    def group_label(medication, group_by)
      case group_by
      when :medication
        medication.name
      when :medication_type
        medication.med_type
      end
    end

    def add_bp_to_bucket(bucket, events, context)
      events_for(events, "blood_pressure").each do |event|
        payload = event.blood_pressure_payload
        next unless payload.reading_context == context

        bucket[:sys] << payload.systolic
        bucket[:dia] << payload.diastolic
      end
    end

    def quantity_taken(payload, medication)
      strength = medication.pill_size_mg.to_f
      return nil unless strength.positive?

      (payload.dose_mg.to_f / strength).round(3)
    end

    def efficiency_status(value)
      return "unknown" if value.nil?
      return "good" if value >= 85
      return "fair" if value >= 75

      "poor"
    end
  end
end
