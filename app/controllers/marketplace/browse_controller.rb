module Marketplace
  class BrowseController < ApplicationController
    def index
      params[:sort_by] ||= "most_recent" unless params[:sort_by].present?

      # Apply filters and sorting
      @products = apply_filters_and_sort(Product.exclude_purchased(current_user))

      # Search functionality for index page
      if params[:query].present?
        @products = @products.where("name LIKE ?", "%#{params[:query]}%")
      end

      if params[:filters].present?
        prod_ids = []

        # Apply category and language filters
        prod_ids.push(ProductCategory.where(category_id: filter_params[:categories]).pluck(:product_id)) if filter_params[:categories].present?
        prod_ids.push(ProductLanguage.where(language_id: filter_params[:languages]).pluck(:product_id)) if filter_params[:languages].present?

        prod_ids = prod_ids.flatten
        @products = @products.where(id: prod_ids)
      end

      # Apply pagination
      @products = @products.page(filter_params[:page]).per(80)

      respond_to do |format|
        format.html
        format.js
      end
    end

    def featured
      params[:sort_by] ||= "most_recent" unless params[:sort_by].present?

      # Filter featured products
      @products = Product.where(featured: true)

      # Search functionality for featured page
      if params[:query].present?
        @products = @products.where("name LIKE ?", "%#{params[:query]}%")
      end

      # Apply filters
      if params[:filters].present?
        prod_ids = []

        # Apply category and language filters
        prod_ids.push(ProductCategory.where(category_id: filter_params[:categories]).pluck(:product_id)) if filter_params[:categories].present?
        prod_ids.push(ProductLanguage.where(language_id: filter_params[:languages]).pluck(:product_id)) if filter_params[:languages].present?
        prod_ids = prod_ids.flatten
        @products = @products.where(id: prod_ids)
      end

      # Apply pagination
      @products = @products.page(filter_params[:page]).per(10)

      respond_to do |format|
        format.html
        format.js
      end
    end

    private

    def filter_params
      # Parse the filters from the URL
      params.delete(:_)
      if params[:filters].is_a?(String)
        begin
          params[:filters] = JSON.parse(params[:filters])
        rescue JSON::ParserError
          params[:filters] = {}
        end
      end
      permitted_params = params.permit(:category, :language, :sort_by, :page, :query, filters: {})

      filters = permitted_params[:filters]&.permit(category: [], language: [], min_price: [], max_price: [], upload_date: [], alphabetical: []) || {}

      {
        categories: ([permitted_params[:category]].compact + (filters[:category] || [])).uniq,
        languages: ([permitted_params[:language]].compact + (filters[:language] || [])).uniq,
        sort_by: permitted_params[:sort_by],
        page: permitted_params[:page],
        query: permitted_params[:query],
        min_price: filters[:min_price],
        max_price: filters[:max_price],
        upload_date: filters[:upload_date],
        alphabetical: filters[:alphabetical]
      }
    end

    def apply_filters_and_sort(resource)

      # Apply filtering if needed (e.g., by category or language)
      resource = resource.includes(:product_categories, :languages, :user, :categories, :product_languages)

      # Category filter
      # resource = resource.where(category_id: filter_params[:categories]) if filter_params[:categories].present?

      # Language filter
      # resource = resource.where(language_id: filter_params[:languages]) if filter_params[:languages].present?

      # Price filter
      if filter_params[:min_price].present?
        resource = resource.where('price_cents >= ?', filter_params[:min_price].to_i * 100)
      end

      if filter_params[:max_price].present?
        resource = resource.where('price_cents <= ?', filter_params[:max_price].to_i * 100)
      end

      # Apply Upload Date filter (Newest or Oldest)
      if filter_params[:upload_date].present?
        case filter_params[:upload_date]
        when "newest"
          resource = resource.order(created_at: :desc)
        when "oldest"
          resource = resource.order(created_at: :asc)
        end
      end

      # Apply Alphabetical filter (A-Z or Z-A)
      if filter_params[:alphabetical].present?
        case filter_params[:alphabetical]
        when "asc"
          resource = resource.order(name: :asc)
        when "desc"
          resource = resource.order(name: :desc)
        end
      end

      # Default sorting if no specific filter is applied
      case filter_params[:sort_by]
      when 'alphabetical_asc'
        resource = resource.order(name: :asc)
      when 'alphabetical_desc'
        resource = resource.order(name: :desc)
      when 'oldest'
        resource = resource.order(created_at: :asc)
      when 'cheapest'
        resource = resource.order(price_cents: :asc)
      when 'most_expensive'
        resource = resource.order(price_cents: :desc)
      when 'most_likes'
        resource = resource.left_joins(:likes)
                .group('products.id')
                .order('COUNT(likes.id) DESC NULLS LAST')
      when 'most_recent'
        resource = resource.order(created_at: :desc)
      else
        resource = resource.order(name: :asc) # Default sorting
      end
      resource
    end
  end
end
