class RemoveUniqueIndexFromProductCategories < ActiveRecord::Migration[7.1]
  def change
    remove_index :product_categories, name: "index_product_categories_on_product_id_and_category_id"
  end
end
