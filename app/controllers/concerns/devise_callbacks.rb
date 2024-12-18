module DeviseCallbacks
  extend ActiveSupport::Concern

  included do
    after_action :sync_products, :sync_cart_items, only: :create
  end

  def sync_products
    return if resource.token.blank?

    # SyncProductsJob.perform_now(resource.id)
  end

  def sync_cart_items
    return if session.id.to_s.blank?

    return unless resource&.persisted?

    SyncCartItemsJob.perform_now(user_id: resource.id, session_id: session.id.to_s)
  end
end
