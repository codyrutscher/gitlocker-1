module Marketplace
class LibraryController < ApplicationController
  include ProductConcern
  def show
    
    session_object = Stripe::Checkout::Session.retrieve(params["session_id"]) rescue nil
    if session_object.present? && session_object["status"] == "complete"
      product_id = session_object["metadata"]["product_id"]
      product = Product.find(product_id)
      product.update(featured: true)
      product.featured_payment_intent.update(status: "paid", session_id: session_object.id)
    end 
    @product = Product.includes(:languages, :categories).friendly.find(params[:id])
    @related_products = @product.related_products
    @more_from_this_creators = @product.more_from_this_creators
    @reviews = @product.reviews.includes(:user).page(params[:page]).per(5)
    @in_cart = (current_user || visitor_user).products_in_cart.include?(@product) || false
    @languages = @product.languages
    @categories = @product.categories
    @cart_item = if @in_cart
                  CartItem.find_by(user: current_user, product: @product)
                 else
                   nil
                 end
    @directory_tree_json = fetch_product_directory_tree(@product)
    render "products/show"
  end
end
end
