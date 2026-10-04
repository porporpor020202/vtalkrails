require "remote_origin_test_case"

class GoogleOauthPageAccessTest < RemoteOriginTestCase
  ORIGINS::SIGN_IN_ORIGINS.each do |origin|
    test "r_#{origin}에서 Google OAuth 로그인 페이지에 접속할 수 있다" do
      visit "#{origin}/session/new"
      assert_current_path "#{origin}/session/new", url: true, wait: 4
      assert_selector "button", text: "Continue with Google", wait: 4
      click_button "Continue with Google"

      assert_text :visible, "Sign in to continue to say one thing", normalize_ws: true, wait: 4
    end
  end
end
