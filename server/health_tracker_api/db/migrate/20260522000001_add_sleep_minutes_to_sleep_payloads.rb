class AddSleepMinutesToSleepPayloads < ActiveRecord::Migration[8.1]
  def change
    add_column :sleep_payloads, :sleep_minutes, :integer

    add_check_constraint :sleep_payloads,
      "sleep_minutes IS NULL OR sleep_minutes > 0",
      name: "chk_sleep_minutes_positive"
  end
end
