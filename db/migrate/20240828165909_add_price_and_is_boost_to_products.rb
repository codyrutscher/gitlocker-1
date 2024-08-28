class AddPriceAndIsBoostToProducts < ActiveRecord::Migration[7.1]
  def change
    add_column :products, :boost_price, :decimal, precision: 10, scale: 2, default: 0.0
    add_column :products, :is_boost, :boolean, default: false
  end
end
