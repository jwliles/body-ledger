# Legacy Metric Mapping

Body Ledger migrates Datacore results, not Datacore implementation details.
Legacy YAML field names are import aliases. Rails canonical names are semantic.
UI labels are presentation.

| Legacy field | Canonical target | Notes |
|---|---|---|
| `wake_sys` | `blood_pressure.systolic`, context `wake` | Wake BP systolic |
| `sleep_sys` | `blood_pressure.systolic`, context `sleep` | Sleep BP systolic |
| `wake_dia` | `blood_pressure.diastolic`, context `wake` | Wake BP diastolic |
| `sleep_dia` | `blood_pressure.diastolic`, context `sleep` | Sleep BP diastolic |
| `wake_hr` | `blood_pressure.pulse_bpm`, context `wake` | Wake pulse/HR |
| `sleep_hr` | `blood_pressure.pulse_bpm`, context `sleep` | Sleep pulse/HR |
| `wake_bp_time` | `blood_pressure.recorded_at`, context `wake` | Timestamp for wake BP |
| `sleep_bp_time` | `blood_pressure.recorded_at`, context `sleep` | Timestamp for sleep BP |
| `wake_meds` | `medication_dose.recorded_at`, context `wake` | Legacy timing alias |
| `sleep_meds` | `medication_dose.recorded_at`, context `sleep` | Legacy timing alias |
| `wake_time` | `sleep.wake_time` | Daily-attributed wake time |
| `bedtime` | `sleep.bedtime` | Daily-attributed bedtime |
| `sleep`, `sleep_mins` | `sleep.sleep_minutes` | Actual slept minutes from tracker/manual entry |
| `weight` | `weight.original_value` | UI can preserve pounds while Rails stores kg |
| `steps` | `activity.steps` | Daily activity metric |
| `date_started` | `medication.date_started` | Medication administrative field |
| `rx_date` | `medication.rx_date` | Later may move to prescription fill events |
| `rx_qty` | `medication.rx_qty` | Later may move to prescription fill events |
| `rx_per_day` | `medication.rx_per_day` | UI label should be units per day |
| `taken_qty` | `derived.medication.taken_qty` | Report projection |
| `last_taken_qty` | `derived.medication.last_taken_qty` | Report projection |
| `dosage` | `derived.medication.daily_dose` | Derived from strength per unit times units per day |
| `dose_unit` | `medication.dose_unit` | Medication administrative field |
| `med_form` | `medication.med_form` | Medication administrative field |
| `last_taken_at` | `derived.medication.last_taken_at` | Report projection |
| `qty` | `report.sleep.linked_medication_quantity` | Sleep report join field |
| `med` | `report.sleep.linked_medication_name` | Sleep report join field |
| `med_type` | `medication.med_type` | Sleep report join field |

Reports own cross-day interpretation. Records keep `date_key` attribution so
Rails can recreate daily-note results while using normalized tables.
