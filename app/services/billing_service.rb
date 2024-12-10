class BillingService
	HOST = ENV['HOST']
	
	def initialize(user)
		@user = user
	end

	def signup_account
		stripe_customer = Stripe::Customer.create({
				email: @user.email,
		})
		@user.update!(stripe_customer: stripe_customer.id)
	end

	def create_checkout_session(stripe_price)
		if @user.stripe_customer == nil
			stripe_customer = Stripe::Customer.create({
					email: @user.email,
			})
			@user.update!(stripe_customer: stripe_customer.id)
		end

		request = {
			customer: @user.stripe_customer,
			payment_method_types: ['card'],
			mode: 'subscription',
			line_items: [
				{price: stripe_price, quantity: 1},
			],
			success_url: "#{HOST}/pricing/process_checkout_result?session_id={CHECKOUT_SESSION_ID}&user_id=#{@user.id}",
			cancel_url: "#{HOST}/pricing?returning=true&result=cancel",
		}

		session = Stripe::Checkout::Session.create(request)
		return session.url
	end

	def process_checkout_result(session_id)
		session = Stripe::Checkout::Session.retrieve(session_id)
		line_items = Stripe::Checkout::Session.list_line_items(session_id)
		update_account_from_product(line_items.data[0].price.product)
		
		ensure_one_active_subscription(session.subscription)
		@user.update!(stripe_subscription: session.subscription)
	end

	def get_active_price_from_subscription
		return nil if @user.stripe_subscription == nil
		return nil if @user.stripe_subscription == 'free'

		subscription = Stripe::Subscription.retrieve(@user.stripe_subscription)
		if subscription.status != 'active' && subscription.status != 'trialing'
			return nil
		end

		price = subscription.items.data[0].price
		return price.id
	end


	def get_product_limit
		return 999999 if !@user.is_new

		price_id = get_active_price_from_subscription
		
		if price_id.present?
			return PriceLimitMapper.get_product_limit(price_id)
		else
			return 10
		end
	end

	private
	def update_account_from_product(stripe_product)
		product = Stripe::Product.retrieve(stripe_product)
	end

	def ensure_one_active_subscription(current_subscription)
		stripe_subscriptions = Stripe::Subscription.list({customer: @user.stripe_customer})
		stripe_subscriptions.each do |stripe_subscription|
			next if stripe_subscription.id == current_subscription
			if stripe_subscription.status != 'canceled'
				Stripe::Subscription.delete(stripe_subscription.id)
			end
		end
	end
end
