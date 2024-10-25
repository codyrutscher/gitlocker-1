class AddCategoryFromCreatorAndLanguageFromCreatorOnProduct < ActiveRecord::Migration[7.1]
  def change
    add_column :products, :more_categories_from_createor, :string, array: true, default: []
    add_column :products, :more_languages_from_createor, :string, array: true, default: []
  end
end
