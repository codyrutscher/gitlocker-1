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
  
  def self.find_plan_name(price_id)
    plans = {
      "FREELANCER" => "price_1QP583SGQ7u76ltnMrfVcDwa",
      "STARTUP" => "price_1QP58USGQ7u76ltnoQpSCcbq",
      "ENTERPRISE" => "price_1QP58uSGQ7u76ltn8xV0JC3E",
      "FREELANCER_YEAR" => "price_1QTGUxSGQ7u76ltndlBm2vt8",
      "STARTUP_YEAR" => "price_1QTGVkSGQ7u76ltn5kG22ySi",
      "ENTERPRISE_YEAR" => "price_1QTGWeSGQ7u76ltnXPgnQANw"
    }
    plan_name = plans.key(price_id)
    plan_name || "Unknown Plan"
  end
end
