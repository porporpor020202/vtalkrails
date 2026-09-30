require "application_system_test_case"
require "minitest/mock"

class VipSystemTest < ApplicationSystemTestCase
  test "free user finds VIP from settings and web checkout waits for verified access" do
    user = users(:korean_native)
    env = ENV.to_h.merge("PADDLE_API_KEY" => "test", "PADDLE_CLIENT_TOKEN" => "test_public")
    price = { "unit_price" => { "amount" => "1499", "currency_code" => "USD" } }
    ENV.stub(:[], ->(key) { env[key] }) do
      Billing::Paddle.stub(:price, price) do
        Billing::Paddle.stub(:checkout, { "id" => "txn_test" }) do
          visit authenticate_by_token_google_oauth_sessions_path(token: user.signed_id(purpose: :native_auth, expires_in: 5.minutes))
          visit settings_path
          click_link "VIP · AI English help →"
          assert_text "$14.99 USD / month"
          assert_text "Renews automatically until canceled."
          page.execute_script(<<~JS)
            window.Paddle = {
              Initialized: true,
              Environment: { set: function() {} },
              Update: function(config) { this.callback = config.eventCallback },
              Checkout: { open: function(config) { window.testTransaction = config.transactionId } }
            }
          JS
          click_button "Subscribe to VIP"
          assert_selector "button[data-vip-target='subscribe']:not([disabled])", wait: 5
          assert_equal "txn_test", page.evaluate_script("window.testTransaction")
          assert_not user.vip?
          grant_vip(user, provider: "paddle")
          page.execute_script("window.Paddle.callback({name: 'checkout.completed'})")
          assert_text "VIP is active", wait: 5
          assert_no_button "Subscribe to VIP"
        end
      end
    end
  end
end
