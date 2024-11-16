module Marketplace
  class SearchResultsController < ApplicationController
    def index
      if params[:search].present?
        @product = sort_products(Product.all, params[:sort_by])
        @product_results = @product.search(params[:search]).page(params[:page]).per(100)

        @user = sort_users(User.all, params[:sort_by])
        @marketplace_creator_results = @user.search(params[:search]).page(params[:page]).per(100)

        @category = sort_categories(Category.all, params[:sort_by])
        @category_results = @category.search(params[:search]).page(params[:page]).per(100)

        @language = sort_languages(Language.all, params[:sort_by])
        @language_results = @language.search(params[:search]).page(params[:page]).per(100)

        if params[:category_id].present?
          @product_results = @product_results.joins(:product_categories)
                                             .where(product_categories: { category_id: params[:category_id] })
        end
      else
        @product_results = []
        @marketplace_creator_results = []
        @category_results = []
        @language_results = []
      end
    end

    private

    def sort_products(products, criteria)
      case criteria
      when 'alphabetical_asc'
        products.order(name: :asc)
      when 'alphabetical_desc'
        products.order(name: :desc)
      when 'cheapest'
        products.order(price_cents: :asc)
      when 'most_expensive'
        products.order(price_cents: :desc)
      when 'most_likes'
      products.left_joins(:likes)
       .group('products.id, pg_search_0a3e27b8ca818264d75c8d.rank')
       .order('COUNT(likes.id) DESC NULLS LAST')
      when 'most_recent'
        products.order(created_at: :desc)
      when 'oldest'
        products.order(created_at: :asc)
      else
        products.order(created_at: :desc)
      end
    end

    def sort_users(users, criteria)
      case criteria
      when 'alphabetical_asc'
        users.order(name: :asc)
      when 'alphabetical_desc'
        users.order(name: :desc)
      when 'most_recent'
        users.order(created_at: :desc)
      when 'oldest'
        users.order(created_at: :asc)
      else
        users.order(created_at: :desc)
      end
    end

    def sort_categories(categories, criteria)
      case criteria
      when 'alphabetical_asc'
        categories.order(name: :asc)
      when 'alphabetical_desc'
        categories.order(name: :desc)
      when 'most_recent'
        categories.order(created_at: :desc)
      when 'oldest'
        categories.order(created_at: :asc)
      else
        categories.order(created_at: :desc)
      end
    end

    def sort_languages(languages, criteria)
      case criteria
      when 'alphabetical_asc'
        languages.order(name: :asc)
      when 'alphabetical_desc'
        languages.order(name: :desc)
      when 'most_recent'
        languages.order(created_at: :desc)
      when 'oldest'
        languages.order(created_at: :asc)
      else
        languages.order(created_at: :desc)
      end
    end
  end
end
