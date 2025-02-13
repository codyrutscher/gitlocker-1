# app/notifications/purchase_notification.rb
class PurchaseNotification < Noticed::Event
  self.table_name = 'notifications'

  # Assuming you have a polymorphic association with recipient
  belongs_to :recipient, polymorphic: true
  belongs_to :buyer, polymorphic: true
  belongs_to :product

  # Store the message in params for easy access
  after_initialize :set_notification_message

  # Example method to generate notification message
  def message
    params[:message]
  end

  private

  def set_notification_message
    self.params ||= {}
    self.params[:message] ||= "#{buyer.username} purchased your #{product.name} product." if buyer.present?
  end
end
