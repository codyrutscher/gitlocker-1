class UserRefactorJob < ApplicationJob
  queue_as :default

  def perform(user_id:)
    user = User.find_by(id: user_id)
    return unless user.stripe_subscription.present?
    subscription = Stripe::Subscription.retrieve(user.stripe_subscription)
    if subscription.status == 'active'
      start_date = Time.at(subscription.start_date)
      after_month = start_date + 1.month
      UpdateUserProductJob.perform_now(user_id: user.id) if after_month.to_date == Date.today
    elsif subscription.status == 'canceled'
      cancel_date = Time.at(subscription.canceled_at)
      cancel_after_month = cancel_date + 1.month
      UpdateUserProductJob.perform_now(user_id: user.id) if cancel_after_month.to_date == Date.today
    end
  end
end
