require "jwt"

module Billing
  class Apple
    def self.token
      now = Time.now.to_i
      JWT.encode({ iss: Config.get("APPLE_IAP_ISSUER_ID"), iat: now, exp: now + 300,
        aud: "appstoreconnect-v1", bid: Config.get("APPLE_BUNDLE_ID") },
        OpenSSL::PKey.read(Config.get("APPLE_IAP_PRIVATE_KEY").gsub('\\n', "\n")),
        "ES256", { kid: Config.get("APPLE_IAP_KEY_ID"), typ: "JWT" })
    end

    def self.snapshot(reference)
      host = ENV.fetch("APPLE_IAP_ENVIRONMENT", "production") == "sandbox" ?
        "api.storekit-sandbox.itunes.apple.com" : "api.storekit.itunes.apple.com"
      data = Http.call(:get, "https://#{host}/inApps/v1/subscriptions/#{Http.segment(reference)}", token: token)
      raise InvalidPurchase, "Wrong app" unless data["bundleId"] == Config.get("APPLE_BUNDLE_ID")
      entries = data.fetch("data", []).flat_map { |group| group.fetch("lastTransactions", []) }
      candidates = entries.filter_map do |entry|
        # These signed values come directly from Apple's authenticated HTTPS API.
        transaction = JWT.decode(entry.fetch("signedTransactionInfo"), nil, false).first
        next unless transaction["productId"] == Config.product("apple")
        next unless transaction["bundleId"] == Config.get("APPLE_BUNDLE_ID")
        renewal = JWT.decode(entry.fetch("signedRenewalInfo"), nil, false).first
        expires = entry["status"] == 4 ? renewal["gracePeriodExpiresDate"] : transaction["expiresDate"]
        { account_token: transaction["appAccountToken"],
          external_id: transaction.fetch("originalTransactionId"),
          product_id: transaction.fetch("productId"),
          status: transaction["revocationDate"] ? "revoked" : { 1 => "active", 4 => "grace" }.fetch(entry["status"], "expired"),
          expires_at: expires && Time.at(expires.to_i / 1000.0),
          auto_renew: renewal["autoRenewStatus"] == 1 }
      end
      candidates.max_by { |item| item[:expires_at] || Time.at(0) } || raise(InvalidPurchase, "No VIP subscription")
    rescue JWT::DecodeError, KeyError
      raise InvalidPurchase, "Invalid Apple subscription"
    end

    def self.notification(signed)
      raise InvalidPurchase, "Invalid notification" if signed.to_s.bytesize > 100_000
      header = JWT.decode(signed, nil, false).last
      raise InvalidPurchase, "Invalid algorithm" unless header["alg"] == "ES256"
      chain = header.fetch("x5c").map { |cert| OpenSSL::X509::Certificate.new(Base64.strict_decode64(cert)) }
      raise InvalidPurchase, "Invalid chain" unless chain.length.between?(2, 3)
      store = OpenSSL::X509::Store.new
      store.add_cert(OpenSSL::X509::Certificate.new(File.read(Rails.root.join("config/certs/apple_root_ca_g3.pem"))))
      raise InvalidPurchase, "Invalid certificate" unless store.verify(chain.first, chain.drop(1))
      raise InvalidPurchase, "Invalid signing certificate" unless chain.first.extensions.any? { |ext| ext.oid == "1.2.840.113635.100.6.11.1" }
      raise InvalidPurchase, "Invalid intermediate certificate" unless chain[1].extensions.any? { |ext| ext.oid == "1.2.840.113635.100.6.2.1" }
      payload = JWT.decode(signed, chain.first.public_key, true, algorithms: [ "ES256" ]).first
      unless payload.dig("data", "bundleId") == Config.get("APPLE_BUNDLE_ID") &&
          payload.dig("data", "environment").to_s.downcase == ENV.fetch("APPLE_IAP_ENVIRONMENT", "production")
        raise InvalidPurchase, "Wrong notification app or environment"
      end
      payload
    rescue JWT::DecodeError, KeyError, ArgumentError, OpenSSL::OpenSSLError
      raise InvalidPurchase, "Invalid Apple notification"
    end
  end
end
