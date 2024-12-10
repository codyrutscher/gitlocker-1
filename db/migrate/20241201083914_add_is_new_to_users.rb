class AddIsNewToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :is_new, :boolean, default: true, null: false
  end
end
