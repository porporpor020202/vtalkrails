module Billing
  module Config
    def self.get(name)
      ENV[name].presence || raise(Error, "Billing is not configured.")
    end

    def self.product(provider)
      get({ "apple" => "APPLE_VIP_PRODUCT_ID", "google" => "GOOGLE_VIP_PRODUCT_ID", "paddle" => "PADDLE_VIP_PRICE_ID" }.fetch(provider))
    end

    def self.paddle_sandbox?
      ENV.fetch("PADDLE_ENVIRONMENT", "sandbox") == "sandbox"
    end
  end
end
