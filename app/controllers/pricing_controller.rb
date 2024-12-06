class PricingController < ApplicationController
  def index
    service = BillingService.new(current_user)	
    @current_price_id = service.get_active_price_from_subscription
  end

  def subscription
    if !current_user.is_new
      service = BillingService.new(current_user)
      session_url = service.create_checkout_session(params[:stripe_price])
      redirect_to session_url, allow_other_host: true
    else
      flash[:notice] = "You already have unlimited access to all features."
      redirect_to pricing_path
    end
  end

  def process_checkout_result
    user = User.find(params[:user_id])
    service = BillingService.new(user)
    service.process_checkout_result(params[:session_id])
    redirect_to "http://localhost:3000/pricing?returning=true&result=success"
  end

  def cancel_subscription
    Stripe::Subscription.cancel(current_user.stripe_subscription)
  rescue Stripe::InvalidRequestError => e
    puts "Error canceling subscription: #{e.message}"
  redirect_to pricing_path
  end
end
