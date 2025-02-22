class SalesUpdateService
  def self.process_payments_for(user)
    previous_balance = user.balance
    recent_payments = user.sales.where("purchases.pending = ? AND purchases.refund = ?", true, false)

    total_sale_value = 0
    recent_payments.each do |payment|
      payment.update(pending: false)
      total_sale_value += payment.price_cents
    end

    total_sale_value *= 0.9
    total_sale_value /= 100 

    if total_sale_value > 0
      user.update(balance: user.balance + total_sale_value, total_earning: user.total_earning + total_sale_value)
    end

    if previous_balance < 100 && user.balance >= 100
      BalanceNotification.create!(recipient: user)
      puts "Notification created for user ##{user.id}. Balance reached $100."
    end

    puts "Processed instant payments for user ##{user.id}. Amount added: $#{total_sale_value}."
  end
end
