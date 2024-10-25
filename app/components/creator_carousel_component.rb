# app/components/product_carousel_component.rb
class CreatorCarouselComponent < ViewComponent::Base
  def initialize(creators)
    @creators = creators
  end

  def paginated_products(page: 1, per_page: 5)
    @creators.each_slice(per_page).to_a[page - 1] || []
  end

  def total_pages(per_page: 5)
    (@creators.size / per_page.to_f).ceil
  end
end
