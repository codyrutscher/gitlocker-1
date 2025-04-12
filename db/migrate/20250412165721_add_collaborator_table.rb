class AddCollaboratorTable < ActiveRecord::Migration[7.1]
  def change
    create_table :product_users do |t|
      t.references :product, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :product_users, [:product_id, :user_id], unique: true
  end
end
