# app/controllers/languages_controller.rb
module Marketplace
class LanguagesController < ApplicationController
  def show
    @language = Language.friendly.find(params[:slug])
    params[:sort_by] ||= "most_recent" unless params[:sort_by].present?
    @products = apply_filters_and_sort(@language&.products).includes([:languages])&.page(params[:page])&.per(100)
  end

  private
  def filter_params
    params.permit(:category, :language, :sort_by)
  end

  def apply_filters_and_sort(resource)
    # Apply filtering if needed (e.g., by category or language)
    resource = resource.includes([:categories]).where(category_id: filter_params[:category]) if filter_params[:category].present?
    resource = resource.where(language_id: filter_params[:language]) if filter_params[:language].present?

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
    end.page(params[:page]).per(50)
  end
end
end
