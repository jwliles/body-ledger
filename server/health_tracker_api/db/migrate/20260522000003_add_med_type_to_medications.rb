class AddMedTypeToMedications < ActiveRecord::Migration[8.1]
  def change
    add_column :medications, :med_type, :string
  end
end
