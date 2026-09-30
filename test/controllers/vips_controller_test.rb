require "test_helper"
require "minitest/mock"

class VipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:korean_native)
    sign_in_as @user
  end

  test "native VIP page contains store purchase and restore but no Paddle token" do
    ENV.stub(:[], ->(key) { key == "PADDLE_CLIENT_TOKEN" ? "public-web-token" : nil }) do
      get vip_path, headers: { "User-Agent" => "vtalk/ios/1.0" }
    end
    assert_response :success
    assert_select "[data-vip-provider-value='apple']"
    assert_select "button", text: "Restore purchases"
    assert_select "[data-vip-paddle-token-value='']"
    refute_includes response.body, "public-web-token"
  end

  test "web checkout is forbidden in both native shells" do
    [ "vtalk/ios/1.0", "vtalk/android/1.0", "VtalkiOS/1.0", "VtalkAndroid/1.0" ].each do |agent|
      post checkout_vip_path, headers: { "User-Agent" => agent }, as: :json
      assert_response :forbidden
    end
  end

  test "existing VIP cannot open another web checkout" do
    grant_vip(@user)
    Billing::Paddle.stub(:checkout, ->(*) { flunk "must not create checkout" }) do
      post checkout_vip_path, as: :json
    end
    assert_response :conflict
  end

  test "web checkout creates transaction but never grants VIP optimistically" do
    Billing::Paddle.stub(:checkout, { "id" => "txn_test" }) do
      post checkout_vip_path, as: :json
    end
    assert_response :success
    assert_equal "txn_test", response.parsed_body["transaction_id"]
    assert_not @user.vip?
  end

  test "client supplied VIP state never grants access" do
    Billing::Apple.stub(:snapshot, ->(*) { raise Billing::InvalidPurchase, "Invalid purchase" }) do
      post verify_vip_path, params: { provider: "apple", purchase_reference: "fake", vip: true }, as: :json
    end
    assert_response :unprocessable_entity
    assert_not @user.vip?
  end

  test "free user cannot request AI but can still open a conversation" do
    partner = users(:english_native)
    room = Room.create!(user: @user, opponent: partner, last_sender: partner)
    get room_path(room)
    assert_response :success
    assert_select "button", text: /Reply with voice/
    post room_ai_assistances_path(room), params: { kind: "suggestions" }, as: :json
    assert_response :payment_required
    assert_equal vip_path, response.parsed_body["vip_url"]
  end

  test "Paddle notifications are authenticated and deduplicated" do
    body = { event_id: "evt_test", event_type: "subscription.updated", data: { id: "sub_test" } }.to_json
    ENV.stub(:[], ->(key) { key == "PADDLE_WEBHOOK_SECRET" ? "secret" : nil }) do
      post "/billing/webhooks/paddle", params: body, headers: { "Content-Type" => "application/json" }
      assert_response :bad_request
      assert_equal 0, BillingEvent.count
      timestamp = Time.now.to_i
      signature = OpenSSL::HMAC.hexdigest("SHA256", "secret", "#{timestamp}:#{body}")
      assert_difference("BillingEvent.count", 1) do
        2.times do
          post "/billing/webhooks/paddle", params: body, headers: {
            "Content-Type" => "application/json", "Paddle-Signature" => "ts=#{timestamp};h1=#{signature}"
          }
          assert_response :success
        end
      end
    end
  end

  test "native users cannot get a Paddle portal redirect" do
    subscription = grant_vip(@user, provider: "paddle")
    post manage_vip_path(subscription_id: subscription.id), headers: { "User-Agent" => "vtalk/ios/1.0" }
    assert_redirected_to vip_path
  end

  test "subscription management enforces ownership" do
    subscription = grant_vip(users(:english_native), provider: "paddle")
    post manage_vip_path(subscription_id: subscription.id)
    assert_response :not_found
  end

  test "subscription terms disclose renewal and cancellation" do
    get vip_terms_path
    assert_response :success
    assert_includes response.body, "automatically renewing"
    assert_includes response.body, "cancel"
  end
end
