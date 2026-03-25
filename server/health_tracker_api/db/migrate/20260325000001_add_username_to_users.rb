class AddUsernameToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :username, :string
    add_index  :users, :username, unique: true

    # Email is now optional (used for account recovery only, not for login)
    change_column_null :users, :email, true
    remove_index :users, :email
    add_index :users, :email, unique: true, where: "email IS NOT NULL"
  end
end
