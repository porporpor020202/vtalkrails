require "googleauth"
require "googleauth/id_tokens"

module Billing
  class Google
    def self.access_token
      credentials = ::Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: StringIO.new(Config.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON")),
        scope: "https://www.googleapis.com/auth/androidpublisher")
      credentials.fetch_access_token!.fetch("access_token")
    rescue Signet::AuthorizationError, JSON::ParserError, ArgumentError
      raise Error, "Google Play credentials could not be used."
    end

    def self.snapshot(reference)
      base = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/#{Http.segment(Config.get("GOOGLE_PLAY_PACKAGE_NAME"))}/purchases"
      token = access_token
      data = Http.call(:get, "#{base}/subscriptionsv2/tokens/#{Http.segment(reference)}", token: token)
      item = data.fetch("lineItems").find { |line| line["productId"] == Config.product("google") &&
        line.dig("offerDetails", "basePlanId") == Config.get("GOOGLE_VIP_BASE_PLAN_ID") }
      raise InvalidPurchase, "Not a VIP subscription" unless item && item["autoRenewingPlan"]
      status = {
        "SUBSCRIPTION_STATE_ACTIVE" => "active",
        "SUBSCRIPTION_STATE_IN_GRACE_PERIOD" => "grace",
        "SUBSCRIPTION_STATE_CANCELED" => "canceled"
      }.fetch(data["subscriptionState"], "inactive")
      account = data.dig("externalAccountIdentifiers", "obfuscatedExternalAccountId")
      raise InvalidPurchase, "Missing subscription owner" if account.blank?
      {
        acknowledge: data["acknowledgementState"] == "ACKNOWLEDGEMENT_STATE_PENDING",
        account_token: account, external_id: reference, product_id: item.fetch("productId"),
        status: status, expires_at: item["expiryTime"] && Time.iso8601(item["expiryTime"]),
        auto_renew: item.dig("autoRenewingPlan", "autoRenewEnabled") == true
      }
    end

    def self.acknowledge(reference, product_id)
      url = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/#{Http.segment(Config.get("GOOGLE_PLAY_PACKAGE_NAME"))}/purchases/subscriptions/#{Http.segment(product_id)}/tokens/#{Http.segment(reference)}:acknowledge"
      Http.call(:post, url, token: access_token, body: {})
    end

    def self.verify_webhook!(authorization)
      bearer = authorization.to_s.delete_prefix("Bearer ")
      payload = ::Google::Auth::IDTokens.verify_oidc(bearer, aud: Config.get("GOOGLE_RTDN_AUDIENCE"))
      unless payload["email_verified"] == true && payload["email"] == Config.get("GOOGLE_RTDN_SERVICE_ACCOUNT_EMAIL")
        raise InvalidPurchase, "Invalid notification identity"
      end
    rescue ::Google::Auth::IDTokens::VerificationError
      raise InvalidPurchase, "Invalid notification identity"
    end
  end
end
