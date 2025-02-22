class StripePayoutService
  def initialize(user, amount)
    @user = user
    @amount = (amount * 100).to_i 
  end

  def process_payout
    return unless @user.stripe_id?
    
    payout = Stripe::Payout.create({
      amount: @amount,
      currency: 'usd',
      method: 'instant'
    }, { stripe_account: @user.stripe_id })

    puts "Instant payout of $#{@amount / 100.0} sent to user ##{@user.id}"
    payout
  rescue Stripe::StripeError => e
    puts "Payout failed: #{e.message}"
    nil
  end
end
