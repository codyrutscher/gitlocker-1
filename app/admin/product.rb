ActiveAdmin.register Product do
  controller do
    defaults finder: :find_by_slug

    def destroy
     
      product = Product.find_by_slug(params[:id])
      return redirect_to admin_products_path, alert: 'Product not found.' unless product

      product_owner = product.user
    
      if product.destroy
        # Create the notification hash
        notification_params = {
          recipient: product_owner,
          params: {
            message: "Your product '#{product.name}' has been removed from the marketplace because it was faulty.",
            reason: "Product deletion by admin"
          }
        }
      
        # Create and save the notification
        notification = Notification.create!(notification_params)
        redirect_to admin_products_path, notice: 'Product was successfully deleted, and the owner has been notified.'
      else
        redirect_to admin_products_path, alert: 'There was an issue deleting the product.'
      end
    end
  end
  permit_params :name, :slug, :price_cents, :user_id, :published, :folder, :video_file, :refund_id, :upload_file,
                category_ids: [], language_ids: [], covers: [], 
                product_categories_attributes: [:id, :category_id, :active, :_destroy],
                product_languages_attributes: [:id, :language_id, :active, :_destroy]

  index do
    selectable_column
    id_column
    column :name
    column :price_cents
    column :user
    column :published
    column :created_at
    actions
  end

  filter :name
  filter :price_cents
  filter :user
  filter :published
  filter :created_at

  form do |f|
    f.inputs do
      f.input :name
      f.input :price_cents
      f.input :user
      f.input :published
      f.input :description
      f.input :folder, as: :file
      f.input :video_file, as: :file
      f.input :upload_file, as: :file

      f.input :covers, as: :file, input_html: { multiple: true }
      f.input :categories, as: :check_boxes, collection: Category.all
      f.input :languages, as: :check_boxes, collection: Language.all
    end
    f.actions
  end

  show do
    attributes_table do
      row :name
      row :slug
      row :price_cents
      row :description
      row :user
      row :published
      row :created_at
      row :updated_at
      row :folder do |product|
        if product.folder.attached?
          link_to product.folder.filename.to_s, rails_blob_path(product.folder, disposition: "attachment")
        end
      end
      row :video_file do |product|
        if product.video_file.attached?
          link_to product.video_file.filename.to_s, rails_blob_path(product.video_file, disposition: "attachment")
        end
      end
      row :covers do |product|
        if product.covers.attached?
          ul do
            product.covers.each do |cover|
              li do
                link_to cover.filename.to_s, rails_blob_path(cover, disposition: "attachment")
              end
            end
          end
        end
      end
      row :categories do |product|
        product.categories.pluck(:name).join(", ")
      end
      row :languages do |product|
        product.languages.pluck(:name).join(", ")
      end
    end
    active_admin_comments
  end
end
