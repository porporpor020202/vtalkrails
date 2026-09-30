require "test_helper"
require "minitest/mock"

class BillingTest < ActiveSupport::TestCase
  setup { @user = users(:korean_native) }

  def snapshot(**attributes)
    { account_token: @user.billing_account_token, external_id: "original-123", product_id: "vip.monthly",
      status: "active", expires_at: 1.month.from_now, auto_renew: true }.merge(attributes)
  end

  test "verified subscription enables VIP and repeated verification is idempotent" do
    Billing::Apple.stub(:snapshot, ->(*) { snapshot }) do
      assert_difference("VipSubscription.count", 1) { Billing::Sync.call("apple", "123", expected_user: @user) }
      assert_no_difference("VipSubscription.count") { Billing::Sync.call("apple", "123", expected_user: @user) }
    end
    assert @user.vip?
  end

  test "a purchase cannot be claimed by a different logged in account" do
    Billing::Apple.stub(:snapshot, ->(*) { snapshot }) do
      assert_no_difference "VipSubscription.count" do
        assert_raises(Billing::InvalidPurchase) { Billing::Sync.call("apple", "123", expected_user: users(:english_native)) }
      end
    end
  end

  test "an already linked purchase cannot move between accounts" do
    Billing::Apple.stub(:snapshot, ->(*) { snapshot }) { Billing::Sync.call("apple", "123") }
    Billing::Apple.stub(:snapshot, ->(*) { snapshot(account_token: users(:english_native).billing_account_token) }) do
      assert_raises(Billing::InvalidPurchase) { Billing::Sync.call("apple", "123") }
    end
    assert_equal @user, VipSubscription.last.user
  end

  test "cancellation retains access until expiry but revocation removes it" do
    Billing::Apple.stub(:snapshot, ->(*) { snapshot(status: "canceled", auto_renew: false) }) { Billing::Sync.call("apple", "123") }
    assert @user.vip?
    travel 32.days do
      assert_not @user.vip?
    end
    Billing::Apple.stub(:snapshot, ->(*) { snapshot(status: "revoked") }) { Billing::Sync.call("apple", "123") }
    assert_not @user.vip?
  end

  test "malformed ownership never reaches a UUID database query" do
    Billing::Apple.stub(:snapshot, ->(*) { snapshot(account_token: "not-a-uuid") }) do
      assert_raises(Billing::InvalidPurchase) { Billing::Sync.call("apple", "123") }
    end
  end

  test "Paddle signature detects tampering and expired messages" do
    ENV.stub(:[], ->(name) { name == "PADDLE_WEBHOOK_SECRET" ? "test-secret" : nil }) do
      body = '{"event_id":"one"}'
      timestamp = Time.now.to_i
      hmac = OpenSSL::HMAC.hexdigest("SHA256", "test-secret", "#{timestamp}:#{body}")
      Billing::Paddle.verify_webhook!(body, "ts=#{timestamp};h1=#{hmac}")
      assert_raises(Billing::InvalidPurchase) { Billing::Paddle.verify_webhook!(body + " ", "ts=#{timestamp};h1=#{hmac}") }
      assert_raises(Billing::InvalidPurchase) { Billing::Paddle.verify_webhook!(body, "ts=#{timestamp - 600};h1=#{hmac}") }
    end
  end

  test "unsigned Apple notifications are rejected" do
    forged = JWT.encode({ data: { bundleId: "example" } }, nil, "none")
    assert_raises(Billing::InvalidPurchase) { Billing::Apple.notification(forged) }
  end

  test "Apple rejects a valid signature from an untrusted certificate" do
    key = OpenSSL::PKey::EC.generate("prime256v1")
    certificate = OpenSSL::X509::Certificate.new
    certificate.version = 2
    certificate.serial = 1
    certificate.subject = certificate.issuer = OpenSSL::X509::Name.parse("/CN=Untrusted")
    certificate.public_key = key
    certificate.not_before = 1.day.ago
    certificate.not_after = 1.day.from_now
    certificate.sign(key, OpenSSL::Digest.new("SHA256"))
    chain = [ Base64.strict_encode64(certificate.to_der) ] * 2
    forged = JWT.encode({ data: { bundleId: "example" } }, key, "ES256", { x5c: chain })
    assert_raises(Billing::InvalidPurchase) { Billing::Apple.notification(forged) }
  end

  test "Paddle snapshot rejects a non VIP price" do
    data = { "items" => [ { "price" => { "id" => "pri_other" } } ] }
    Billing::Config.stub(:product, "pri_vip") do
      Billing::Paddle.stub(:api, data) do
        assert_raises(Billing::InvalidPurchase) { Billing::Paddle.snapshot("sub_other") }
      end
    end
  end

  test "Paddle cancellation scheduled at period end keeps VIP active" do
    data = { "id" => "sub_vip", "items" => [ { "price" => { "id" => "pri_vip" } } ],
      "status" => "active", "current_billing_period" => { "ends_at" => 1.month.from_now.iso8601 },
      "scheduled_change" => { "action" => "cancel" }, "custom_data" => { "account_token" => @user.billing_account_token } }
    Billing::Config.stub(:product, "pri_vip") do
      Billing::Paddle.stub(:api, data) do
        result = Billing::Paddle.snapshot("sub_vip")
        assert_equal "active", result[:status]
        assert_equal false, result[:auto_renew]
      end
    end
  end
end
