class AddConsumedTimestepToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :consumed_timestep, :integer
  end
end
