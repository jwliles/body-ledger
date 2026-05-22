module Reports
  class LegacyMetricMap
    FIELD_MAP = {
      "wake_sys" => {
        canonical: "blood_pressure.systolic",
        context: "wake",
        ui_label: "Wake systolic BP"
      },
      "sleep_sys" => {
        canonical: "blood_pressure.systolic",
        context: "sleep",
        ui_label: "Sleep systolic BP"
      },
      "wake_dia" => {
        canonical: "blood_pressure.diastolic",
        context: "wake",
        ui_label: "Wake diastolic BP"
      },
      "sleep_dia" => {
        canonical: "blood_pressure.diastolic",
        context: "sleep",
        ui_label: "Sleep diastolic BP"
      },
      "wake_hr" => {
        canonical: "blood_pressure.pulse_bpm",
        context: "wake",
        ui_label: "Wake HR"
      },
      "sleep_hr" => {
        canonical: "blood_pressure.pulse_bpm",
        context: "sleep",
        ui_label: "Sleep HR"
      },
      "wake_bp_time" => {
        canonical: "blood_pressure.recorded_at",
        context: "wake",
        ui_label: "Wake BP time"
      },
      "sleep_bp_time" => {
        canonical: "blood_pressure.recorded_at",
        context: "sleep",
        ui_label: "Sleep BP time"
      },
      "wake_meds" => {
        canonical: "medication_dose.recorded_at",
        context: "wake",
        ui_label: "Wake meds"
      },
      "sleep_meds" => {
        canonical: "medication_dose.recorded_at",
        context: "sleep",
        ui_label: "Sleep meds"
      },
      "wake_time" => {
        canonical: "sleep.wake_time",
        ui_label: "Wake time"
      },
      "bedtime" => {
        canonical: "sleep.bedtime",
        ui_label: "Bedtime"
      },
      "sleep" => {
        canonical: "sleep.sleep_minutes",
        ui_label: "Sleep"
      },
      "sleep_mins" => {
        canonical: "sleep.sleep_minutes",
        ui_label: "Sleep"
      },
      "weight" => {
        canonical: "weight.original_value",
        ui_label: "Weight"
      },
      "steps" => {
        canonical: "activity.steps",
        ui_label: "Steps"
      },
      "date_started" => {
        canonical: "medication.date_started",
        ui_label: "Date started"
      },
      "rx_date" => {
        canonical: "medication.rx_date",
        ui_label: "Rx date"
      },
      "rx_qty" => {
        canonical: "medication.rx_qty",
        ui_label: "Rx qty"
      },
      "rx_per_day" => {
        canonical: "medication.rx_per_day",
        ui_label: "Units per day"
      },
      "taken_qty" => {
        canonical: "derived.medication.taken_qty",
        ui_label: "Taken qty"
      },
      "last_taken_qty" => {
        canonical: "derived.medication.last_taken_qty",
        ui_label: "Last taken qty"
      },
      "dosage" => {
        canonical: "derived.medication.daily_dose",
        ui_label: "Daily dose"
      },
      "dose_unit" => {
        canonical: "medication.dose_unit",
        ui_label: "Dose unit"
      },
      "med_form" => {
        canonical: "medication.med_form",
        ui_label: "Form"
      },
      "last_taken_at" => {
        canonical: "derived.medication.last_taken_at",
        ui_label: "Last taken"
      },
      "qty" => {
        canonical: "report.sleep.linked_medication_quantity",
        ui_label: "Qty"
      },
      "med" => {
        canonical: "report.sleep.linked_medication_name",
        ui_label: "Medication"
      },
      "med_type" => {
        canonical: "report.sleep.linked_medication_type",
        ui_label: "Medication type"
      }
    }.freeze

    def self.as_json
      FIELD_MAP
    end
  end
end
