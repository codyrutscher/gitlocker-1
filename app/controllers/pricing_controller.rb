class PricingController < ApplicationController
  HOST = ENV['HOST']

  def index
    @pricing_type = 'monthly'
    service = BillingService.new(current_user)	
    @current_price_id = service.get_active_price_from_subscription
  end

  def toggle_pricing
    service = BillingService.new(current_user)	
    @current_price_id = service.get_active_price_from_subscription
    @pricing_type = params[:pricing_type]
    render turbo_stream: turbo_stream.replace("pricing_section", partial: "pricing/pricing_#{@pricing_type}")
  end

  def subscription
    if current_user.is_new
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
    redirect_to "#{HOST}/pricing?returning=true&result=success"
  end

  def cancel_subscription
    begin
      subscription = Stripe::Subscription.delete(current_user.stripe_subscription)
      Rails.logger.info "Subscription canceled successfully" if subscription
      flash[:notice] = "Subscription canceled successfully."
      redirect_to pricing_path
    rescue Stripe::InvalidRequestError => e
      Rails.logger.error "Error canceling subscription: #{e.message}"
      flash[:alert] = "There was an issue canceling your subscription. Please try again."
      redirect_to pricing_path
    end
  end
end
