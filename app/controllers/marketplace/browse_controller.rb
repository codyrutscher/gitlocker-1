module Marketplace
  class BrowseController < ApplicationController
    def index
      params[:sort_by] ||= "most_recent" unless params[:sort_by].present?
      @products = apply_filters_and_sort(Product.exclude_purchased(current_user))

      if params[:filters].present?
        prod_ids = []
        prod_ids.push(ProductCategory.where(category_id: filter_params[:categories]).pluck(:product_id)) if filter_params[:categories].present?
        prod_ids.push(ProductLanguage.where(language_id: filter_params[:languages]).pluck(:product_id)) if filter_params[:languages].present?
        
        prod_ids = prod_ids.flatten
        @products = @products.where(id: prod_ids)
      end

      @products = @products.page(filter_params[:page]).per(80)

      respond_to do |format|
        format.html
        format.js
      end
    end

    private

    def filter_params
      params.delete(:_)
      if params[:filters].is_a?(String)
        begin
          params[:filters] = JSON.parse(params[:filters])
        rescue JSON::ParserError
          params[:filters] = {}
        end
      end
      permitted_params = params.permit(:category, :language, :sort_by, :page, filters: {})

      filters = permitted_params[:filters]&.permit(category: [], language: [], min_price: [], max_price: []) || {}

      {
        categories: ([permitted_params[:category]].compact + (filters[:category] || [])).uniq,
        languages: ([permitted_params[:language]].compact + (filters[:language] || [])).uniq,
        sort_by: permitted_params[:sort_by],
        page: permitted_params[:page],
        min_price: filters[:min_price],
        max_price: filters[:max_price]
      }
    end

    def apply_filters_and_sort(resource)
      resource = resource.includes(:product_categories, :languages, :user, :categories, :product_languages)

      # Apply filtering if needed (e.g., by category or language)
      resource = resource.where(category_id: filter_params[:category]) if filter_params[:category].present?
      resource = resource.where(language_id: filter_params[:language]) if filter_params[:language].present?
      
      # Price filter
      if filter_params[:min_price].present?
        resource = resource.where('price_cents >= ?', filter_params[:min_price].to_i * 100)
      end

      if filter_params[:max_price].present?
        resource = resource.where('price_cents <= ?', filter_params[:max_price].to_i * 100)
      end

      resource = resource.with_attached_covers
      
      case filter_params[:sort_by]
      when 'alphabetical_asc'
        resource.order(name: :asc)
      when 'alphabetical_desc'
        resource.order(name: :desc)
      when 'oldest'
        resource.order(created_at: :asc)
      when 'cheapest'
        resource.order(price_cents: :asc)
      when 'most_expensive'
        resource.order(price_cents: :desc)
      when 'most_likes'
        resource.left_joins(:likes)
                .group('products.id')
                .order('COUNT(likes.id) DESC NULLS LAST')
      when 'most_recent'
        resource.order(created_at: :desc)
      else
        resource.order(name: :asc) # Default sorting
      end
    end
  end
end
