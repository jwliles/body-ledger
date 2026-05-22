class AddTimingContextToMedicationDosePayloads < ActiveRecord::Migration[8.1]
  def change
    add_column :medication_dose_payloads, :timing_context, :string

    add_check_constraint :medication_dose_payloads,
      "timing_context IS NULL OR timing_context IN ('wake','sleep','other')",
      name: "chk_medication_dose_timing_context"
  end
end
