module PriceLimitMapper
  PRICE_LIMITS = {
    ENV['FREELANCER'] => 20,
    ENV['FREELANCER_YEAR'] => 20,
    ENV['STARTUP'] => 30,
    ENV['STARTUP_YEAR'] => 30,
    ENV['ENTERPRISE'] => 99999999,
    ENV['ENTERPRISE_YEAR'] => 99999999,
  }.freeze

  def self.get_product_limit(price_id)
    PRICE_LIMITS[price_id] || 10
  end
end
