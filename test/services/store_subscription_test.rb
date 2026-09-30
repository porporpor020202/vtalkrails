require "test_helper"
require "minitest/mock"

class StoreSubscriptionTest < ActiveSupport::TestCase
  setup { @user = users(:korean_native) }

  def config
    Billing::Config.stub(:get, ->(key) {
      { "GOOGLE_PLAY_PACKAGE_NAME" => "test.app", "GOOGLE_VIP_BASE_PLAN_ID" => "monthly",
        "APPLE_BUNDLE_ID" => "test.app" }.fetch(key)
    }) do
      Billing::Config.stub(:product, "vip.monthly") { yield }
    end
  end

  def google_data(state: "SUBSCRIPTION_STATE_ACTIVE", expiry: 1.month.from_now)
    { "subscriptionState" => state, "acknowledgementState" => "ACKNOWLEDGEMENT_STATE_PENDING",
      "externalAccountIdentifiers" => { "obfuscatedExternalAccountId" => @user.billing_account_token },
      "lineItems" => [ { "productId" => "vip.monthly", "expiryTime" => expiry.iso8601,
        "offerDetails" => { "basePlanId" => "monthly" },
        "autoRenewingPlan" => { "autoRenewEnabled" => true } } ] }
  end

  test "Google active subscription is bound to owner before acknowledgement" do
    calls = []
    config do
      Billing::Google.stub(:access_token, "test-access") do
        Billing::Http.stub(:call, ->(method, url, **options) {
          calls << [ method, url ]
          method == :get ? google_data : {}
        }) do
          result = Billing::Sync.call("google", "purchase-token", expected_user: @user)
          assert result.active?
          assert_equal [ :get, :post ], calls.map(&:first)
          assert_includes calls.last.last, ":acknowledge"
        end
      end
    end
  end

  test "Google purchase for another account is never acknowledged" do
    config do
      Billing::Google.stub(:access_token, "test-access") do
        Billing::Http.stub(:call, ->(method, *_args, **_options) {
          assert_equal :get, method
          google_data
        }) do
          assert_raises(Billing::InvalidPurchase) do
            Billing::Sync.call("google", "purchase-token", expected_user: users(:english_native))
          end
        end
      end
    end
  end

  test "Google pending and on hold purchases do not grant VIP or get acknowledged" do
    config do
      Billing::Google.stub(:access_token, "test-access") do
        %w[SUBSCRIPTION_STATE_PENDING SUBSCRIPTION_STATE_ON_HOLD SUBSCRIPTION_STATE_PAUSED].each do |state|
          Billing::Http.stub(:call, ->(method, *_args, **_options) {
            assert_equal :get, method
            google_data(state: state)
          }) do
            subscription = Billing::Sync.call("google", "purchase-token", expected_user: @user)
            assert_not subscription.active?
            assert_not @user.vip?
          end
        end
      end
    end
  end

  test "Apple grace period and revoked transactions are distinguished" do
    transaction = { "originalTransactionId" => "original", "bundleId" => "test.app",
      "productId" => "vip.monthly", "appAccountToken" => @user.billing_account_token,
      "expiresDate" => 1.day.ago.to_i * 1000 }
    renewal = { "autoRenewStatus" => 1, "gracePeriodExpiresDate" => 2.days.from_now.to_i * 1000 }
    config do
      Billing::Apple.stub(:token, "api-token") do
        [ false, true ].each do |revoked|
          transaction["revocationDate"] = revoked ? Time.current.to_i * 1000 : nil
          body = { "bundleId" => "test.app", "data" => [ { "lastTransactions" => [
            { "status" => 4, "signedTransactionInfo" => JWT.encode(transaction, nil, "none"),
              "signedRenewalInfo" => JWT.encode(renewal, nil, "none") }
          ] } ] }
          # JWS bodies here are read only from the mocked authenticated server API;
          # notification signatures have independent rejection tests.
          Billing::Http.stub(:call, body) do
            result = Billing::Apple.snapshot("original")
            assert_equal revoked ? "revoked" : "grace", result[:status]
            assert result[:expires_at].future?
          end
        end
      end
    end
  end

  test "webhook retries fetch current state rather than replaying old entitlement" do
    event = BillingEvent.create!(provider: "apple", event_id: "renewal", reference: "original")
    calls = 0
    Billing::Sync.stub(:call, ->(*) { calls += 1 }) do
      BillingEventJob.perform_now(event.id)
      BillingEventJob.perform_now(event.id)
    end
    assert_equal 1, calls
    assert event.reload.processed_at
  end
end
