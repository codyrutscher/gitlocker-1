module PriceLimitMapper
  PRICE_LIMITS = {
    ENV['FREELANCER'] => 1,
    ENV['STARTUP'] => 30,
    ENV['ENTERPRISE'] => 99999999
}.freeze

  def self.get_product_limit(price_id)
    PRICE_LIMITS[price_id] || 10
  end
end
