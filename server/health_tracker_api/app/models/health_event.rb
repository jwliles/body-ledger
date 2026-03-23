class HealthEvent < ApplicationRecord
  include ImmutableRecord

  # ── Mutable exceptions ──────────────────────────────────────────────────
  # Only these two columns may be updated after insert. Everything else is
  # append-only. No updated_at column exists on this table.
  def self.mutable_columns
    %i[is_superseded confirmation_status]
  end

  # ── Associations ────────────────────────────────────────────────────────
  belongs_to :user
  belongs_to :device

  # Amendment chain
  belongs_to :superseded_event, class_name: "HealthEvent",
    foreign_key: :supersedes_id, optional: true
  has_many :amendments, class_name: "HealthEvent",
    foreign_key: :supersedes_id, inverse_of: :superseded_event

  # Per-metric payload (exactly one will be present per event)
  has_one :blood_pressure_payload
  has_one :weight_payload
  has_one :sleep_payload
  has_one :activity_payload
  has_one :nutrition_payload
  has_one :symptom_payload
  has_one :medication_dose_payload

  # ── Enums ───────────────────────────────────────────────────────────────
  # Using string columns + CHECK constraints (not PG enums) per design decision.
  METRIC_TYPES = %w[blood_pressure weight sleep activity nutrition symptom medication_dose].freeze
  CONFIRMATION_STATUSES = %w[pending confirmed rejected].freeze

  # ── Validations ─────────────────────────────────────────────────────────
  validates :metric_type,         inclusion: { in: METRIC_TYPES }
  validates :confirmation_status, inclusion: { in: CONFIRMATION_STATUSES }
  validates :date_key,            presence: true
  validates :recorded_at,         presence: true
  validates :client_uuid,         presence: true
  validates :client_uuid,         uniqueness: { scope: :user_id }

  # ── Callbacks ───────────────────────────────────────────────────────────
  before_validation :derive_date_key, on: :create

  # ── Scopes ──────────────────────────────────────────────────────────────
  scope :current,    -> { where(is_superseded: false) }
  scope :superseded, -> { where(is_superseded: true) }
  scope :confirmed,  -> { where(confirmation_status: "confirmed") }
  scope :pending,    -> { where(confirmation_status: "pending") }

  # ── Amendment ───────────────────────────────────────────────────────────
  # Creates an amendment event and atomically marks self as superseded.
  # The amendment inherits the same metric_type; caller passes new payload attrs
  # via the standard nested attributes pattern.
  def amend!(attributes = {})
    transaction do
      amendment = self.class.create!(
        attributes.merge(
          user:        user,
          device:      device,
          metric_type: metric_type,
          date_key:    date_key,
          supersedes_id: id
        )
      )
      update_column(:is_superseded, true)
      amendment
    end
  end

  private

  # Sleep events are attributed to the wake date (DATE of sleep_end).
  # All other events use DATE(recorded_at) in the user's time zone.
  # Time-zone awareness lives here so it is never duplicated in clients.
  def derive_date_key
    return if date_key.present?

    if metric_type == "sleep" && sleep_payload&.sleep_end.present?
      tz = ActiveSupport::TimeZone[user&.time_zone || "UTC"]
      self.date_key = sleep_payload.sleep_end.in_time_zone(tz).to_date
    elsif recorded_at.present?
      tz = ActiveSupport::TimeZone[user&.time_zone || "UTC"]
      self.date_key = recorded_at.in_time_zone(tz).to_date
    end
  end
end
