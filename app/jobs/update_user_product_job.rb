class UpdateUserProductJob < ApplicationJob
  queue_as :default

  def perform(user_id:)
    user = User.find_by(id: user_id)
    service = BillingService.new(user)	
    user_limit = service.get_product_limit
    if user.products.count > user_limit
      limit_up_products = user.products.recent.limit(user.products.count - user_limit)
      limit_up_products.destroy_all
    end
  end
end
