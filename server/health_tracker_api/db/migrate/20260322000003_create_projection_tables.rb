class CreateProjectionTables < ActiveRecord::Migration[8.1]
  def change
    # ── daily_summaries ────────────────────────────────────────────────────
    # Materialized summary per (user, date, metric_type).
    # Rebuilt by projectors whenever new events arrive or stale flag is set.
    create_table :daily_summaries do |t|
      t.references :user,        null: false, foreign_key: true
      t.date       :summary_date, null: false
      t.string     :metric_type,  null: false

      t.jsonb  :summary_data, null: false, default: {}
      t.string :status,       null: false, default: "projected"
      # projected → confirmed | stale

      t.timestamps
    end

    add_check_constraint :daily_summaries,
      "metric_type IN ('blood_pressure','weight','sleep','activity','nutrition','symptom','medication_dose')",
      name: "chk_daily_summaries_metric_type"
    add_check_constraint :daily_summaries,
      "status IN ('projected','confirmed','stale')",
      name: "chk_daily_summaries_status"

    add_index :daily_summaries, [ :user_id, :summary_date, :metric_type ], unique: true,
      name: "idx_daily_summaries_user_date_metric"
    add_index :daily_summaries, :summary_data, using: :gin,
      name: "idx_daily_summaries_summary_data_gin"
    add_index :daily_summaries, :status,
      where: "status = 'stale'", name: "idx_daily_summaries_stale"

    # ── medication_inventory_snapshots ─────────────────────────────────────
    create_table :medication_inventory_snapshots do |t|
      t.references :user,       null: false, foreign_key: true
      t.references :medication, null: false, foreign_key: true

      t.date    :snapshot_date,    null: false
      t.decimal :calculated_count, null: false, precision: 8, scale: 3
      # Pills expected from last reconciliation event + doses recorded since.

      t.decimal :physical_count,   precision: 8, scale: 3
      # Set when user physically counts pills; NULL until then.

      # Generated column: discrepancy (positive = more pills than expected).
      # NULL when physical_count is not yet set.
      t.virtual :discrepancy, type: :decimal,
        as: "CASE WHEN physical_count IS NOT NULL THEN physical_count - calculated_count ELSE NULL END",
        stored: true

      t.string :status, null: false, default: "projected"
      # projected | confirmed | stale

      t.timestamps
    end

    add_check_constraint :medication_inventory_snapshots,
      "status IN ('projected','confirmed','stale')",
      name: "chk_med_inventory_status"

    add_index :medication_inventory_snapshots,
      [ :user_id, :medication_id, :snapshot_date ], unique: true,
      name: "idx_med_inventory_user_med_date"

    # ── correlation_snapshots ──────────────────────────────────────────────
    # Pearson r between two metric types over a trailing window.
    create_table :correlation_snapshots do |t|
      t.references :user, null: false, foreign_key: true

      t.string  :metric_a, null: false
      t.string  :metric_b, null: false
      t.integer :window_days, null: false, default: 30  # trailing window size

      t.date    :computed_on,   null: false
      t.integer :matched_days,  null: false, default: 0
      # Days where both metrics have data in the window.

      t.decimal :pearson_r, precision: 6, scale: 4
      # NULL when matched_days < 14 (not enough data).

      # Generated column: is this correlation statistically meaningful?
      t.virtual :is_valid, type: :boolean,
        as: "matched_days >= 14",
        stored: true

      t.timestamps
    end

    add_check_constraint :correlation_snapshots,
      "metric_a < metric_b",
      name: "chk_correlation_metric_order"
      # Canonical ordering prevents duplicate (a,b) vs (b,a) pairs.

    add_check_constraint :correlation_snapshots,
      "pearson_r IS NULL OR (pearson_r BETWEEN -1.0 AND 1.0)",
      name: "chk_correlation_pearson_range"

    add_index :correlation_snapshots,
      [ :user_id, :metric_a, :metric_b, :window_days, :computed_on ], unique: true,
      name: "idx_correlation_unique"
    add_index :correlation_snapshots, :is_valid,
      where: "is_valid = TRUE", name: "idx_correlation_valid"

    # ── sync_cursors ───────────────────────────────────────────────────────
    # Per-device dual cursor: timestamp + event-id for reliable incremental sync.
    create_table :sync_cursors do |t|
      t.references :device, null: false, foreign_key: true

      t.datetime :last_synced_at             # wall-clock high-watermark
      t.bigint   :last_event_id              # row-id high-watermark (gap-safe)
      t.string   :direction, null: false     # upload | download | both

      t.timestamps
    end

    add_check_constraint :sync_cursors,
      "direction IN ('upload','download','both')",
      name: "chk_sync_cursors_direction"

    add_index :sync_cursors, [ :device_id, :direction ], unique: true,
      name: "idx_sync_cursors_device_direction"

    # ── sync_logs ──────────────────────────────────────────────────────────
    # Immutable audit trail of every sync operation.
    create_table :sync_logs do |t|
      t.references :device, null: false, foreign_key: true

      t.string   :operation,    null: false  # push | pull | conflict_resolve
      t.integer  :events_count, null: false, default: 0
      t.string   :status,       null: false  # success | partial | failed
      t.jsonb    :details,      default: {}  # error messages, conflict refs, etc.

      t.datetime :started_at,  null: false
      t.datetime :finished_at
      # No updated_at — log entries are immutable once written.
      t.datetime :created_at, null: false
    end

    add_check_constraint :sync_logs,
      "operation IN ('push','pull','conflict_resolve')",
      name: "chk_sync_logs_operation"
    add_check_constraint :sync_logs,
      "status IN ('success','partial','failed')",
      name: "chk_sync_logs_status"

    add_index :sync_logs, [ :device_id, :started_at ]
    add_index :sync_logs, :status,
      where: "status = 'failed'", name: "idx_sync_logs_failed"
  end
end
