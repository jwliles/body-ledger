class AllowSleepMinutesWithoutInterval < ActiveRecord::Migration[8.1]
  def change
    change_column_null :sleep_payloads, :sleep_start, true
    change_column_null :sleep_payloads, :sleep_end, true

    add_check_constraint :sleep_payloads,
      "sleep_minutes IS NOT NULL OR (sleep_start IS NOT NULL AND sleep_end IS NOT NULL)",
      name: "chk_sleep_payload_has_minutes_or_interval"
  end
end
