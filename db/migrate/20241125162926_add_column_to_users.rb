class AddColumnToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :stripe_customer, :string
    add_column :users, :stripe_subscription, :string
  end
end
