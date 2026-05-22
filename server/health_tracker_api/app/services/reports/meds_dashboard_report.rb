module Reports
  class MedsDashboardReport < BaseReport
    def call
      range_start = start_date || end_date - 29.days
      events = current_events(range_start, end_date).to_a
      dose_events = events_for(events, "medication_dose").sort_by(&:recorded_at).reverse

      {
        id: "meds_dashboard",
        title: "Meds Dashboard",
        explanation: "Tracks medication setup, inventory-facing quantities, recent dose logs, and adherence using medication dose records.",
        period: {
          start_date: range_start,
          end_date: end_date
        },
        sections: [
          basic_med_info(dose_events),
          recent_dose_logs(dose_events),
          adherence_tracking(dose_events, range_start, end_date)
        ],
        legacy_fields: Reports::LegacyMetricMap.as_json.slice(
          "date_started", "rx_date", "rx_qty", "rx_per_day", "taken_qty",
          "last_taken_qty", "dosage", "dose_unit", "med_form", "last_taken_at"
        )
      }
    end

    private

    def basic_med_info(dose_events)
      rows = user.medications.order(:name).map do |medication|
        med_doses = dose_events.select { |event| event.medication_dose_payload&.medication_id == medication.id }
        quantities = med_doses.map { |event| quantity_taken(event.medication_dose_payload, medication) }
        last_event = med_doses.max_by(&:recorded_at)

        {
          id: medication.id,
          name: medication.name,
          date_started: medication.date_started,
          rx_date: medication.rx_date,
          rx_qty: medication.rx_qty,
          rx_per_day: medication.rx_per_day,
          taken_qty: source(quantities.compact.sum, "derived_from_dose_events"),
          last_taken_qty: source(quantity_taken(last_event&.medication_dose_payload, medication), "derived_from_latest_dose"),
          dosage: source(daily_dose(medication), "derived_from_strength_and_units_per_day"),
          dose_unit: medication.dose_unit,
          med_form: medication.med_form,
          last_taken_at: source(last_event&.recorded_at&.iso8601, "derived_from_latest_dose")
        }
      end

      {
        id: "basic_med_info",
        title: "Basic Med Info",
        columns: %w[name date_started rx_date rx_qty rx_per_day taken_qty last_taken_qty dosage dose_unit med_form last_taken_at],
        rows: rows
      }
    end

    def recent_dose_logs(dose_events)
      rows = dose_events.first(30).map do |event|
        payload = event.medication_dose_payload
        medication = payload.medication
        {
          date: event.date_key,
          recorded_at: event.recorded_at.iso8601,
          medication: medication.name,
          quantity: source(quantity_taken(payload, medication), "derived_from_dose_and_strength"),
          dose_mg: payload.dose_mg,
          dose_type: payload.dose_type
        }
      end

      {
        id: "recent_dose_logs",
        title: "Recent Dose Logs",
        columns: %w[date recorded_at medication quantity dose_mg dose_type],
        rows: rows
      }
    end

    def adherence_tracking(dose_events, range_start, range_end)
      days = (range_end - range_start).to_i + 1
      rows = user.medications.where(is_active: true)
      rows = rows.map do |medication|
        med_doses = dose_events.select do |event|
          event.medication_dose_payload&.medication_id == medication.id &&
            event.medication_dose_payload.dose_type != "missed"
        end
        taken = med_doses.filter_map { |event| quantity_taken(event.medication_dose_payload, medication) }.sum
        expected = medication.rx_per_day ? medication.rx_per_day.to_f * days : nil

        {
          medication: medication.name,
          taken_qty: source(taken, "derived_from_dose_events"),
          expected_qty: source(expected, expected ? "derived_from_rx_per_day" : "unknown"),
          adherence_percent: source(expected&.positive? ? ((taken / expected) * 100).round(1) : nil, "derived")
        }
      end

      {
        id: "adherence_tracking",
        title: "Adherence Tracking",
        columns: %w[medication taken_qty expected_qty adherence_percent],
        rows: rows
      }
    end

    def quantity_taken(payload, medication)
      return nil unless payload

      strength = medication.pill_size_mg.to_f
      return nil unless strength.positive?

      (payload.dose_mg.to_f / strength).round(3)
    end

    def daily_dose(medication)
      strength = medication.pill_size_mg.to_f
      units = medication.rx_per_day.to_f
      return nil unless strength.positive? && units.positive?

      (strength * units).round(3)
    end
  end
end
