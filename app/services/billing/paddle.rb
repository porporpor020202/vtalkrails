module Billing
  class Paddle
    def self.api(method, path, body = nil)
      host = Config.paddle_sandbox? ? "sandbox-api.paddle.com" : "api.paddle.com"
      Http.call(method, "https://#{host}/#{path}", token: Config.get("PADDLE_API_KEY"), body: body).fetch("data")
    end

    def self.price
      result = api(:get, "prices/#{Http.segment(Config.product("paddle"))}")
      unless result.dig("unit_price", "currency_code") == "USD" &&
          result["billing_cycle"] == { "interval" => "month", "frequency" => 1 } &&
          result["trial_period"].nil? && result["status"] == "active"
        raise Error, "Configure an active monthly USD VIP price without a trial."
      end
      result
    end

    def self.checkout(user)
      price
      if user.paddle_checkout_id.present?
        previous = api(:get, "transactions/#{Http.segment(user.paddle_checkout_id)}")
        return previous if %w[draft ready].include?(previous["status"])
        if previous["status"] != "canceled"
          raise Error, "A previous checkout is being processed. Contact support before starting another subscription."
        end
      end
      transaction = api(:post, "transactions", {
        items: [ { price_id: Config.product("paddle"), quantity: 1 } ],
        collection_mode: "automatic",
        currency_code: "USD",
        custom_data: { account_token: user.billing_account_token },
        checkout: { url: Config.get("BILLING_PUBLIC_URL").delete_suffix("/") + "/vip" }
      })
      user.update!(paddle_checkout_id: transaction.fetch("id"))
      transaction
    end

    def self.snapshot(reference)
      data = api(:get, "subscriptions/#{Http.segment(reference)}")
      raise InvalidPurchase, "Not a VIP subscription" unless data.fetch("items").any? { |item| item.dig("price", "id") == Config.product("paddle") }
      expiry = data.dig("current_billing_period", "ends_at") || data["ended_at"] || data["canceled_at"]
      {
        account_token: data.dig("custom_data", "account_token"),
        external_id: data.fetch("id"), customer_id: data["customer_id"],
        product_id: Config.product("paddle"),
        status: { "active" => "active", "canceled" => "expired" }.fetch(data["status"], "inactive"),
        expires_at: expiry && Time.iso8601(expiry),
        auto_renew: data["status"] == "active" && data.dig("scheduled_change", "action") != "cancel"
      }
    end

    def self.portal(subscription)
      api(:post, "customers/#{Http.segment(subscription.customer_id)}/portal-sessions",
        { subscription_ids: [ subscription.external_id ] }).dig("urls", "general", "overview")
    end

    def self.verify_webhook!(body, header)
      fields = header.to_s.split(";").map { |part| part.strip.split("=", 2) }
      timestamp = fields.assoc("ts")&.last
      raise InvalidPurchase, "Invalid signature" unless timestamp&.match?(/\A\d+\z/) && (Time.now.to_i - timestamp.to_i).abs <= 300
      expected = OpenSSL::HMAC.hexdigest("SHA256", Config.get("PADDLE_WEBHOOK_SECRET"), "#{timestamp}:#{body}")
      valid = fields.select { |key, _| key == "h1" }.any? { |_, signature| ActiveSupport::SecurityUtils.secure_compare(expected, signature.to_s) }
      raise InvalidPurchase, "Invalid signature" unless valid
    end
  end
end
