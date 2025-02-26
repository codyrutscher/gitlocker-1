module Marketplace
class CheckoutController < ApplicationController
  before_action :authenticate_user!

  def index
    @cart_items = current_user.cart_items.includes(:product)
  end

  def create
    ActiveRecord::Base.transaction do
      if current_user.cart_items.any? { |cart_item| cart_item.product.price_cents.zero? }
        proceed_with_free_purchase
      else
        proceed_with_stripe_payment
      end
    end
  rescue Stripe::CardError => e
    flash[:error] = e.message
    redirect_to marketplace_cart_path
  end

  def success_payment
    ActiveRecord::Base.transaction do
      total_cents = params[:total_cents].to_i
      purchases_json = JSON.parse(params[:purchases])

      purchases = purchases_json.map { |purchase_attributes| Purchase.new(purchase_attributes) }

      payment = current_user.payments.order(created_at: :desc).find_by(total_cents: total_cents)

      if payment.nil? || payment.stripe_session_id.nil?
        raise ActiveRecord::RecordNotFound, "Payment or session ID not found."
      end

      session_object = Stripe::Checkout::Session.retrieve(payment.stripe_session_id)
      payment_intent_id = session_object.payment_intent
      payment_intent = Stripe::PaymentIntent.retrieve(payment_intent_id)
      charge_id = payment_intent.charges.data.first.id

      Purchase.import(purchases, on_duplicate_key_ignore: true, synchronize: purchases)
      payment.update!(stripe_charge_id: charge_id)

      current_user.reload.cart_items.destroy_all
      purchases.each do |purchase|
        PurchaseNotification.create!(recipient: purchase.product.user, buyer: current_user, product: purchase.product)
        purchase.payment = payment
        purchase.save

        SalesUpdateService.process_payments_for(purchase.product.user)
        StripePayoutService.new(purchase.product.user, purchase.price_cents / 100).process_payout
      end
    end
    
    redirect_to marketplace_purchases_url, notice: 'Payment successful! Your order has been placed.'
  end

  def cancel_payment
    flash[:error] = 'Payment canceled.'
    redirect_to marketplace_checkout_url
  end

  def refund 
    refund = Stripe::Refund.create({
            charge: params["stripe_charge_id"],
            amount: params["price_cents"],
          })

    purchase = Purchase.find(params["purchase_id"])
    if refund["status"] == "succeeded"
      purchase.update(refund_id: refund["id"], refund: true) 
      message = "Payment Successfully Refunded"
    else 
      message = refund["status"]
    end 

    redirect_to admin_payment_path(purchase.payment), notice: message
  end 

  private

  def proceed_with_free_purchase
    purchases = current_user.cart_items.includes(:product).map do |cart_item|
      Purchase.new(
        user: current_user,
        product: cart_item.product,
        price_cents: cart_item.product.price_cents,
        price_currency: cart_item.product.price_currency
      )
    end

    ActiveRecord::Base.transaction do
      payment = Payment.create(user: current_user, total_cents: 0)

      purchases.each { |purchase| purchase.payment = payment }

      Purchase.import(purchases, on_duplicate_key_ignore: true, synchronize: purchases)

      current_user.reload.cart_items.destroy_all
      purchases.each do |purchase|
        PurchaseNotification.create!(recipient: purchase.product.user, buyer: current_user, product: purchase.product)
      end
    end

    redirect_to marketplace_purchases_url, notice: 'Free product added to sales!'
  end

  def proceed_with_stripe_payment
    purchases = current_user.cart_items.includes(:product).map do |cart_item|
      Purchase.new(
        user: current_user,
        product: cart_item.product,
        price_cents: cart_item.product.price_cents,
        price_currency: cart_item.product.price_currency
      )
    end

    total_cents = purchases.map(&:price_cents).sum

    transaction_fee_cents = (total_cents * 0.029 + 30).to_i
    total_with_fee = total_cents + transaction_fee_cents

    line_items = purchases.map do |purchase|
      {
        price_data: {
          currency: purchase.price_currency,
          product_data: {
            name: purchase.product.name,
          },
          unit_amount: purchase.price_cents,
        },
        quantity: 1,
      }
    end

    line_items << {
      price_data: {
        currency: 'usd',
        product_data: {
          name: 'Transaction Fee',
        },
        unit_amount: transaction_fee_cents,
      },
      quantity: 1,
    }

    session = Stripe::Checkout::Session.create(
      payment_method_types: ['card'],
      line_items: line_items,
      mode: 'payment',
      automatic_tax: { enabled: true },
      success_url: marketplace_success_payment_url(total_cents: total_cents, purchases: purchases.to_json),
      cancel_url: marketplace_cancel_payment_url,
    )

    payment = Payment.create!(user: current_user, total_cents: total_cents, stripe_session_id: session.id)
    redirect_to session.url, allow_other_host: true
  end
end
end
