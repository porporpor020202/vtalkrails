require "application_system_test_case"
require_relative "../test_helpers/oauth_test_config"

class AppleOauthPageAccessTest < ApplicationSystemTestCase
  setup do
    @previous_run_server = Capybara.run_server
    @previous_always_include_port = Capybara.always_include_port

    Capybara.run_server = false
    Capybara.always_include_port = false
  end

  teardown do
    Capybara.run_server = @previous_run_server
    Capybara.always_include_port = @previous_always_include_port
  end

  OAuthTestConfig::LOGIN_ORIGINS.each do |origin|
    test "r_#{origin}에서 Apple OAuth 로그인 페이지에 접속할 수 있다" do
      visit "#{origin}/session/new"
      assert_current_path "#{origin}/session/new", url: true, wait: 4
      assert_selector "button", text: "Continue with Apple", wait: 4
      click_button "Continue with Apple"

      assert_selector "h1#contentheader", text: "Use your Apple Account to sign in to say one thing.", normalize_ws: true, wait: 4
    end
  end
end
