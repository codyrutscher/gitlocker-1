class AddTemplateIdInProduct < ActiveRecord::Migration[7.1]
  def change
    add_column :products, :template_id, :integer
  end
end
