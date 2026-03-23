class CreatePayloadTables < ActiveRecord::Migration[8.1]
  def change
    # ── medications (reference catalogue) ─────────────────────────────────
    create_table :medications do |t|
      t.references :user, null: false, foreign_key: true

      t.string  :name,        null: false
      t.string  :strength,    null: false       # e.g. "10mg"
      t.boolean :is_prn,      null: false, default: false
      t.jsonb   :scheduled_times                # e.g. ["08:00","20:00"] — null for PRN
      t.decimal :pill_size_mg, precision: 8, scale: 3  # for reconciliation math
      t.boolean :is_active,   null: false, default: true

      t.timestamps
    end

    add_index :medications, [ :user_id, :name ], unique: true

    # ── blood_pressure_payloads ────────────────────────────────────────────
    create_table :blood_pressure_payloads, id: false do |t|
      t.bigint :health_event_id, null: false, primary_key: true

      t.integer :systolic,  null: false  # mmHg
      t.integer :diastolic, null: false  # mmHg
      t.integer :pulse                   # bpm, optional
      t.string  :reading_context, null: false  # wake | sleep
    end

    add_check_constraint :blood_pressure_payloads,
      "systolic BETWEEN 40 AND 300",
      name: "chk_bp_systolic_range"
    add_check_constraint :blood_pressure_payloads,
      "diastolic BETWEEN 20 AND 200",
      name: "chk_bp_diastolic_range"
    add_check_constraint :blood_pressure_payloads,
      "reading_context IN ('wake','sleep')",
      name: "chk_bp_reading_context"

    add_foreign_key :blood_pressure_payloads, :health_events,
      column: :health_event_id, primary_key: :id, name: "fk_bp_payloads_event"

    add_index :blood_pressure_payloads, :reading_context,
      name: "idx_bp_reading_context"

    # ── weight_payloads ────────────────────────────────────────────────────
    create_table :weight_payloads, id: false do |t|
      t.bigint  :health_event_id, null: false, primary_key: true

      t.decimal :value_kg,       null: false, precision: 6, scale: 3  # canonical
      t.string  :original_unit               # kg | lb | st — for display round-trip
      t.decimal :original_value, precision: 7, scale: 3               # as entered
    end

    add_check_constraint :weight_payloads,
      "value_kg > 0 AND value_kg < 700",
      name: "chk_weight_value_kg_range"
    add_check_constraint :weight_payloads,
      "original_unit IS NULL OR original_unit IN ('kg','lb','st')",
      name: "chk_weight_original_unit"

    add_foreign_key :weight_payloads, :health_events,
      column: :health_event_id, primary_key: :id, name: "fk_weight_payloads_event"

    # ── sleep_payloads ─────────────────────────────────────────────────────
    create_table :sleep_payloads, id: false do |t|
      t.bigint   :health_event_id, null: false, primary_key: true

      t.datetime :sleep_start, null: false
      t.datetime :sleep_end,   null: false

      # Generated column: derived duration in minutes.
      # Stored so queries can ORDER/filter without recomputing.
      t.virtual :duration_minutes, type: :integer,
        as: "EXTRACT(EPOCH FROM (sleep_end - sleep_start)) / 60",
        stored: true
    end

    add_check_constraint :sleep_payloads,
      "sleep_end > sleep_start",
      name: "chk_sleep_end_after_start"

    add_foreign_key :sleep_payloads, :health_events,
      column: :health_event_id, primary_key: :id, name: "fk_sleep_payloads_event"

    # ── activity_payloads ──────────────────────────────────────────────────
    create_table :activity_payloads, id: false do |t|
      t.bigint :health_event_id, null: false, primary_key: true

      t.string  :activity_type,    null: false   # walk | run | cycle | swim | etc.
      t.integer :duration_minutes, null: false
      t.decimal :distance_km,      precision: 8, scale: 3
      t.integer :steps
      t.integer :heart_rate_avg    # bpm
      t.integer :calories_burned
    end

    add_check_constraint :activity_payloads,
      "duration_minutes > 0",
      name: "chk_activity_duration_positive"

    add_foreign_key :activity_payloads, :health_events,
      column: :health_event_id, primary_key: :id, name: "fk_activity_payloads_event"

    # ── nutrition_payloads ─────────────────────────────────────────────────
    create_table :nutrition_payloads, id: false do |t|
      t.bigint :health_event_id, null: false, primary_key: true

      t.string  :meal_type           # breakfast | lunch | dinner | snack | supplement

      # Hot macro columns (indexed/constrained)
      t.decimal :calories_kcal,  precision: 8, scale: 2
      t.decimal :protein_g,      precision: 7, scale: 2
      t.decimal :fat_g,          precision: 7, scale: 2
      t.decimal :carbohydrate_g, precision: 7, scale: 2
      t.decimal :fiber_g,        precision: 7, scale: 2
      t.decimal :sugar_g,        precision: 7, scale: 2
      t.decimal :sodium_mg,      precision: 8, scale: 2

      # Micronutrients: flexible bag — not hot enough to warrant columns
      t.jsonb :micronutrients, default: {}
    end

    add_check_constraint :nutrition_payloads,
      "meal_type IS NULL OR meal_type IN ('breakfast','lunch','dinner','snack','supplement')",
      name: "chk_nutrition_meal_type"

    add_foreign_key :nutrition_payloads, :health_events,
      column: :health_event_id, primary_key: :id, name: "fk_nutrition_payloads_event"

    add_index :nutrition_payloads, :micronutrients, using: :gin,
      name: "idx_nutrition_micronutrients_gin"

    # ── symptom_payloads ───────────────────────────────────────────────────
    create_table :symptom_payloads, id: false do |t|
      t.bigint :health_event_id, null: false, primary_key: true

      t.string  :symptom_code,   null: false  # e.g. "headache", "fatigue"
      t.integer :severity,       null: false  # 1–10
      t.string  :body_location               # e.g. "left_temple"
    end

    add_check_constraint :symptom_payloads,
      "severity BETWEEN 1 AND 10",
      name: "chk_symptom_severity_range"

    add_foreign_key :symptom_payloads, :health_events,
      column: :health_event_id, primary_key: :id, name: "fk_symptom_payloads_event"

    add_index :symptom_payloads, :symptom_code

    # ── medication_dose_payloads ───────────────────────────────────────────
    create_table :medication_dose_payloads, id: false do |t|
      t.bigint :health_event_id, null: false, primary_key: true

      t.references :medication, null: false, foreign_key: true, index: true

      t.decimal :dose_mg, null: false, precision: 8, scale: 3
      t.string  :dose_type, null: false  # scheduled | prn | missed | reconciliation
      # NOTE: 'missed' is forbidden when medication.is_prn — enforced in Rails model
    end

    add_check_constraint :medication_dose_payloads,
      "dose_mg > 0",
      name: "chk_med_dose_positive"
    add_check_constraint :medication_dose_payloads,
      "dose_type IN ('scheduled','prn','missed','reconciliation')",
      name: "chk_med_dose_type"

    add_foreign_key :medication_dose_payloads, :health_events,
      column: :health_event_id, primary_key: :id, name: "fk_med_dose_payloads_event"
  end
end
