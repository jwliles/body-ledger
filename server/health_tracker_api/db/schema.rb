# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_22_000004) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "activity_payloads", primary_key: "health_event_id", force: :cascade do |t|
    t.string "activity_type", null: false
    t.integer "calories_burned"
    t.decimal "distance_km", precision: 8, scale: 3
    t.integer "duration_minutes", null: false
    t.integer "heart_rate_avg"
    t.integer "steps"
    t.check_constraint "duration_minutes > 0", name: "chk_activity_duration_positive"
  end

  create_table "blood_pressure_payloads", primary_key: "health_event_id", force: :cascade do |t|
    t.integer "diastolic", null: false
    t.integer "pulse"
    t.string "reading_context", null: false
    t.integer "systolic", null: false
    t.index ["reading_context"], name: "idx_bp_reading_context"
    t.check_constraint "diastolic >= 20 AND diastolic <= 200", name: "chk_bp_diastolic_range"
    t.check_constraint "reading_context::text = ANY (ARRAY['wake'::character varying, 'sleep'::character varying]::text[])", name: "chk_bp_reading_context"
    t.check_constraint "systolic >= 40 AND systolic <= 300", name: "chk_bp_systolic_range"
  end

  create_table "correlation_snapshots", force: :cascade do |t|
    t.date "computed_on", null: false
    t.datetime "created_at", null: false
    t.virtual "is_valid", type: :boolean, as: "(matched_days >= 14)", stored: true
    t.integer "matched_days", default: 0, null: false
    t.string "metric_a", null: false
    t.string "metric_b", null: false
    t.decimal "pearson_r", precision: 6, scale: 4
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "window_days", default: 30, null: false
    t.index ["is_valid"], name: "idx_correlation_valid", where: "(is_valid = true)"
    t.index ["user_id", "metric_a", "metric_b", "window_days", "computed_on"], name: "idx_correlation_unique", unique: true
    t.index ["user_id"], name: "index_correlation_snapshots_on_user_id"
    t.check_constraint "metric_a::text < metric_b::text", name: "chk_correlation_metric_order"
    t.check_constraint "pearson_r IS NULL OR pearson_r >= '-1.0'::numeric AND pearson_r <= 1.0", name: "chk_correlation_pearson_range"
  end

  create_table "daily_summaries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "metric_type", null: false
    t.string "status", default: "projected", null: false
    t.jsonb "summary_data", default: {}, null: false
    t.date "summary_date", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["status"], name: "idx_daily_summaries_stale", where: "((status)::text = 'stale'::text)"
    t.index ["summary_data"], name: "idx_daily_summaries_summary_data_gin", using: :gin
    t.index ["user_id", "summary_date", "metric_type"], name: "idx_daily_summaries_user_date_metric", unique: true
    t.index ["user_id"], name: "index_daily_summaries_on_user_id"
    t.check_constraint "metric_type::text = ANY (ARRAY['blood_pressure'::character varying, 'weight'::character varying, 'sleep'::character varying, 'activity'::character varying, 'nutrition'::character varying, 'symptom'::character varying, 'medication_dose'::character varying]::text[])", name: "chk_daily_summaries_metric_type"
    t.check_constraint "status::text = ANY (ARRAY['projected'::character varying, 'confirmed'::character varying, 'stale'::character varying]::text[])", name: "chk_daily_summaries_status"
  end

  create_table "devices", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "last_seen_at"
    t.string "name", null: false
    t.string "platform", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["token_digest"], name: "index_devices_on_token_digest", unique: true
    t.index ["user_id"], name: "index_devices_on_user_id"
  end

  create_table "health_events", force: :cascade do |t|
    t.uuid "client_uuid", null: false
    t.string "confirmation_status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.date "date_key", null: false
    t.bigint "device_id", null: false
    t.boolean "is_superseded", default: false, null: false
    t.string "metric_type", null: false
    t.text "notes"
    t.datetime "recorded_at", null: false
    t.bigint "supersedes_id"
    t.bigint "user_id", null: false
    t.index ["client_uuid"], name: "index_health_events_on_client_uuid"
    t.index ["device_id"], name: "index_health_events_on_device_id"
    t.index ["is_superseded"], name: "idx_health_events_current", where: "(is_superseded = false)"
    t.index ["supersedes_id"], name: "index_health_events_on_supersedes_id"
    t.index ["user_id", "client_uuid"], name: "index_health_events_on_user_id_and_client_uuid", unique: true
    t.index ["user_id", "date_key", "metric_type"], name: "index_health_events_on_user_id_and_date_key_and_metric_type"
    t.index ["user_id"], name: "index_health_events_on_user_id"
    t.check_constraint "confirmation_status::text = ANY (ARRAY['pending'::character varying, 'confirmed'::character varying, 'rejected'::character varying]::text[])", name: "chk_health_events_confirmation_status"
    t.check_constraint "metric_type::text = ANY (ARRAY['blood_pressure'::character varying, 'weight'::character varying, 'sleep'::character varying, 'activity'::character varying, 'nutrition'::character varying, 'symptom'::character varying, 'medication_dose'::character varying]::text[])", name: "chk_health_events_metric_type"
  end

  create_table "medication_dose_payloads", primary_key: "health_event_id", force: :cascade do |t|
    t.decimal "dose_mg", precision: 8, scale: 3, null: false
    t.string "dose_type", null: false
    t.bigint "medication_id", null: false
    t.string "timing_context"
    t.index ["medication_id"], name: "index_medication_dose_payloads_on_medication_id"
    t.check_constraint "dose_mg > 0::numeric", name: "chk_med_dose_positive"
    t.check_constraint "dose_type::text = ANY (ARRAY['scheduled'::character varying, 'prn'::character varying, 'missed'::character varying, 'reconciliation'::character varying]::text[])", name: "chk_med_dose_type"
    t.check_constraint "timing_context IS NULL OR (timing_context::text = ANY (ARRAY['wake'::character varying, 'sleep'::character varying, 'other'::character varying]::text[]))", name: "chk_medication_dose_timing_context"
  end

  create_table "medication_inventory_snapshots", force: :cascade do |t|
    t.decimal "calculated_count", precision: 8, scale: 3, null: false
    t.datetime "created_at", null: false
    t.virtual "discrepancy", type: :decimal, as: "\nCASE\n    WHEN (physical_count IS NOT NULL) THEN (physical_count - calculated_count)\n    ELSE NULL::numeric\nEND", stored: true
    t.bigint "medication_id", null: false
    t.decimal "physical_count", precision: 8, scale: 3
    t.date "snapshot_date", null: false
    t.string "status", default: "projected", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["medication_id"], name: "index_medication_inventory_snapshots_on_medication_id"
    t.index ["user_id", "medication_id", "snapshot_date"], name: "idx_med_inventory_user_med_date", unique: true
    t.index ["user_id"], name: "index_medication_inventory_snapshots_on_user_id"
    t.check_constraint "status::text = ANY (ARRAY['projected'::character varying, 'confirmed'::character varying, 'stale'::character varying]::text[])", name: "chk_med_inventory_status"
  end

  create_table "medications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date_started"
    t.decimal "dosage", precision: 8, scale: 3
    t.string "dose_unit", default: "mg", null: false
    t.boolean "is_active", default: true, null: false
    t.boolean "is_prn", default: false, null: false
    t.string "med_form"
    t.string "med_type"
    t.string "name", null: false
    t.decimal "pill_size_mg", precision: 8, scale: 3
    t.date "rx_date"
    t.decimal "rx_per_day", precision: 8, scale: 3
    t.decimal "rx_qty", precision: 8, scale: 3
    t.jsonb "scheduled_times"
    t.string "strength", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "name"], name: "index_medications_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_medications_on_user_id"
  end

  create_table "nutrition_payloads", primary_key: "health_event_id", force: :cascade do |t|
    t.decimal "calories_kcal", precision: 8, scale: 2
    t.decimal "carbohydrate_g", precision: 7, scale: 2
    t.decimal "fat_g", precision: 7, scale: 2
    t.decimal "fiber_g", precision: 7, scale: 2
    t.string "meal_type"
    t.jsonb "micronutrients", default: {}
    t.decimal "protein_g", precision: 7, scale: 2
    t.decimal "sodium_mg", precision: 8, scale: 2
    t.decimal "sugar_g", precision: 7, scale: 2
    t.index ["micronutrients"], name: "idx_nutrition_micronutrients_gin", using: :gin
    t.check_constraint "meal_type IS NULL OR (meal_type::text = ANY (ARRAY['breakfast'::character varying, 'lunch'::character varying, 'dinner'::character varying, 'snack'::character varying, 'supplement'::character varying]::text[]))", name: "chk_nutrition_meal_type"
  end

  create_table "sleep_payloads", primary_key: "health_event_id", force: :cascade do |t|
    t.virtual "duration_minutes", type: :integer, as: "(EXTRACT(epoch FROM (sleep_end - sleep_start)) / (60)::numeric)", stored: true
    t.datetime "sleep_end"
    t.integer "sleep_minutes"
    t.datetime "sleep_start"
    t.check_constraint "sleep_end > sleep_start", name: "chk_sleep_end_after_start"
    t.check_constraint "sleep_minutes IS NOT NULL OR sleep_start IS NOT NULL AND sleep_end IS NOT NULL", name: "chk_sleep_payload_has_minutes_or_interval"
    t.check_constraint "sleep_minutes IS NULL OR sleep_minutes > 0", name: "chk_sleep_minutes_positive"
  end

  create_table "symptom_payloads", primary_key: "health_event_id", force: :cascade do |t|
    t.string "body_location"
    t.integer "severity", null: false
    t.string "symptom_code", null: false
    t.index ["symptom_code"], name: "index_symptom_payloads_on_symptom_code"
    t.check_constraint "severity >= 1 AND severity <= 10", name: "chk_symptom_severity_range"
  end

  create_table "sync_cursors", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "device_id", null: false
    t.string "direction", null: false
    t.bigint "last_event_id"
    t.datetime "last_synced_at"
    t.datetime "updated_at", null: false
    t.index ["device_id", "direction"], name: "idx_sync_cursors_device_direction", unique: true
    t.index ["device_id"], name: "index_sync_cursors_on_device_id"
    t.check_constraint "direction::text = ANY (ARRAY['upload'::character varying, 'download'::character varying, 'both'::character varying]::text[])", name: "chk_sync_cursors_direction"
  end

  create_table "sync_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "details", default: {}
    t.bigint "device_id", null: false
    t.integer "events_count", default: 0, null: false
    t.datetime "finished_at"
    t.string "operation", null: false
    t.datetime "started_at", null: false
    t.string "status", null: false
    t.index ["device_id", "started_at"], name: "index_sync_logs_on_device_id_and_started_at"
    t.index ["device_id"], name: "index_sync_logs_on_device_id"
    t.index ["status"], name: "idx_sync_logs_failed", where: "((status)::text = 'failed'::text)"
    t.check_constraint "operation::text = ANY (ARRAY['push'::character varying, 'pull'::character varying, 'conflict_resolve'::character varying]::text[])", name: "chk_sync_logs_operation"
    t.check_constraint "status::text = ANY (ARRAY['success'::character varying, 'partial'::character varying, 'failed'::character varying]::text[])", name: "chk_sync_logs_status"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.integer "consumed_timestep"
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "email"
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.datetime "locked_at"
    t.boolean "otp_required_for_login", default: false, null: false
    t.string "otp_secret"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.string "time_zone", default: "UTC", null: false
    t.string "unconfirmed_email"
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.string "username"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true, where: "(email IS NOT NULL)"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "weight_payloads", primary_key: "health_event_id", force: :cascade do |t|
    t.string "original_unit"
    t.decimal "original_value", precision: 7, scale: 3
    t.decimal "value_kg", precision: 6, scale: 3, null: false
    t.check_constraint "original_unit IS NULL OR (original_unit::text = ANY (ARRAY['kg'::character varying, 'lb'::character varying, 'st'::character varying]::text[]))", name: "chk_weight_original_unit"
    t.check_constraint "value_kg > 0::numeric AND value_kg < 700::numeric", name: "chk_weight_value_kg_range"
  end

  add_foreign_key "activity_payloads", "health_events", name: "fk_activity_payloads_event"
  add_foreign_key "blood_pressure_payloads", "health_events", name: "fk_bp_payloads_event"
  add_foreign_key "correlation_snapshots", "users"
  add_foreign_key "daily_summaries", "users"
  add_foreign_key "devices", "users"
  add_foreign_key "health_events", "devices"
  add_foreign_key "health_events", "health_events", column: "supersedes_id", name: "fk_health_events_supersedes"
  add_foreign_key "health_events", "users"
  add_foreign_key "medication_dose_payloads", "health_events", name: "fk_med_dose_payloads_event"
  add_foreign_key "medication_dose_payloads", "medications"
  add_foreign_key "medication_inventory_snapshots", "medications"
  add_foreign_key "medication_inventory_snapshots", "users"
  add_foreign_key "medications", "users"
  add_foreign_key "nutrition_payloads", "health_events", name: "fk_nutrition_payloads_event"
  add_foreign_key "sleep_payloads", "health_events", name: "fk_sleep_payloads_event"
  add_foreign_key "symptom_payloads", "health_events", name: "fk_symptom_payloads_event"
  add_foreign_key "sync_cursors", "devices"
  add_foreign_key "sync_logs", "devices"
  add_foreign_key "weight_payloads", "health_events", name: "fk_weight_payloads_event"
end
