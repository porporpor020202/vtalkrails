require "application_system_test_case"
require_relative "../test_helpers/google_oauth_test_config"

class GoogleOauthPageAccessTest < ApplicationSystemTestCase
  setup do
    @previous_run_server = Capybara.run_server
    @previous_always_include_port = Capybara.always_include_port
    # Use each live site's own port, not Rails' temporary test server port.
    Capybara.run_server = false
    Capybara.always_include_port = false
  end

  teardown do
    Capybara.run_server = @previous_run_server
    Capybara.always_include_port = @previous_always_include_port
  end

  GoogleOauthTestConfig::GOOGLE_LOGIN_ORIGINS.each do |origin|
    test "#{origin}에서 Google OAuth 로그인 페이지에 접속할 수 있다" do
      skip "CI 환경에서는 실제 사이트의 Google OAuth 페이지 접속 테스트를 실행하지 않습니다." if ENV["CI"]

      visit "#{origin}/session/new"
      assert_current_path "#{origin}/session/new", url: true, wait: 15
      assert_selector "button", text: "Continue with Google", wait: 15
      click_button "Continue with Google"

      assert_current_path %r{\Ahttps://accounts\.google\.com/}, url: true, wait: 20
      # Google's error page uses the same host; verify the login form as well.
      assert_selector 'input[type="email"]', visible: true, wait: 20
    end
  end
end
