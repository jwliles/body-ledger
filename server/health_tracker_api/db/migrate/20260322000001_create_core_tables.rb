class CreateCoreTables < ActiveRecord::Migration[8.1]
  def change
    # ── users ──────────────────────────────────────────────────────────────
    create_table :users do |t|
      # Devise-compatible columns
      t.string  :email,              null: false
      t.string  :encrypted_password, null: false, default: ""

      # Devise recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      # Devise rememberable
      t.datetime :remember_created_at

      # Devise trackable
      t.integer  :sign_in_count,      null: false, default: 0
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip

      # Devise confirmable
      t.string   :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string   :unconfirmed_email

      # Devise lockable
      t.integer  :failed_attempts, null: false, default: 0
      t.string   :unlock_token
      t.datetime :locked_at

      # 2FA (e.g. devise-two-factor)
      t.string  :otp_secret
      t.boolean :otp_required_for_login, null: false, default: false

      t.string  :time_zone, null: false, default: "UTC"

      t.timestamps
    end

    add_index :users, :email,                  unique: true
    add_index :users, :reset_password_token,   unique: true
    add_index :users, :confirmation_token,     unique: true
    add_index :users, :unlock_token,           unique: true

    # ── devices ────────────────────────────────────────────────────────────
    create_table :devices do |t|
      t.references :user, null: false, foreign_key: true

      t.string :name,         null: false            # human label, e.g. "Pixel 9"
      t.string :platform,     null: false            # android | desktop | web
      t.string :token_digest, null: false            # bcrypt of device auth token
      t.datetime :last_seen_at
      t.boolean  :is_active,  null: false, default: true

      t.timestamps
    end

    add_index :devices, :token_digest, unique: true

    # ── health_events ──────────────────────────────────────────────────────
    create_table :health_events do |t|
      t.references :user,   null: false, foreign_key: true
      t.references :device, null: false, foreign_key: true

      # ---- metric classification ----
      t.string :metric_type, null: false
      # widened via new migration when new types ship; NOT a PG enum

      # ---- temporal ----
      t.date     :date_key,    null: false  # attribution date (sleep → wake date)
      t.datetime :recorded_at, null: false  # wall-clock moment of measurement

      # ---- amendment chain ----
      t.bigint  :supersedes_id                         # FK to health_events.id
      t.boolean :is_superseded, null: false, default: false

      # ---- idempotency ----
      t.uuid :client_uuid, null: false

      # ---- confirmation workflow ----
      t.string :confirmation_status, null: false, default: "pending"
      # pending → confirmed | rejected

      # ---- optional notes ----
      t.text :notes

      # Intentionally NO updated_at — immutability enforced at model layer.
      # Only created_at so the ledger is auditable.
      t.datetime :created_at, null: false
    end

    # Constraints
    add_check_constraint :health_events,
      "metric_type IN ('blood_pressure','weight','sleep','activity','nutrition','symptom','medication_dose')",
      name: "chk_health_events_metric_type"

    add_check_constraint :health_events,
      "confirmation_status IN ('pending','confirmed','rejected')",
      name: "chk_health_events_confirmation_status"

    # Self-referential FK for amendment chain
    add_foreign_key :health_events, :health_events,
      column: :supersedes_id, name: "fk_health_events_supersedes"

    # Indexes
    add_index :health_events, :client_uuid                              # idempotency lookup
    add_index :health_events, [ :user_id, :client_uuid ], unique: true  # idempotency constraint
    add_index :health_events, [ :user_id, :date_key, :metric_type ]     # common query pattern
    add_index :health_events, :supersedes_id                            # chain traversal
    add_index :health_events, :is_superseded,                           # partial below is what matters
      where: "is_superseded = FALSE", name: "idx_health_events_current"
  end
end
