class AddTrackingFieldsToMedications < ActiveRecord::Migration[8.1]
  def change
    add_column :medications, :date_started, :date
    add_column :medications, :rx_date, :date
    add_column :medications, :rx_qty, :decimal, precision: 8, scale: 3
    add_column :medications, :rx_per_day, :decimal, precision: 8, scale: 3
    add_column :medications, :dosage, :decimal, precision: 8, scale: 3
    add_column :medications, :dose_unit, :string, null: false, default: "mg"
    add_column :medications, :med_form, :string
  end
end
