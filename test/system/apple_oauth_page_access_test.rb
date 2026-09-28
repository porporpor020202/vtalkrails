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

  [ OAuthTestConfig::APPLE_LOGIN_ORIGIN ].each do |origin|
    test "#{origin}에서 Apple OAuth 로그인 페이지에 접속할 수 있다" do
      skip "CI 환경에서는 실제 사이트의 Apple OAuth 페이지 접속 테스트를 실행하지 않습니다." if ENV["CI"]

      visit "#{origin}/session/new"
      assert_current_path "#{origin}/session/new", url: true, wait: 4
      assert_selector "button", text: "Continue with Apple", wait: 4
      click_button "Continue with Apple"

      assert_current_path(
        %r{\Ahttps://appleid\.apple\.com/auth/authorize(?:\?|$)},
        url: true,
        wait: 4
      )

      assert_selector "h1#contentheader",
        text: "Use your Apple Account to sign in to say one thing.",
        normalize_ws: true, wait: 4
      assert_selector "input#account_name_text_field", visible: true, wait: 4
    end
  end
end
