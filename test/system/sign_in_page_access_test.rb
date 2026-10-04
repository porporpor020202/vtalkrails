require "remote_origin_test_case"

class SignInPageAccessTest < RemoteOriginTestCase
  ORIGINS::SIGN_IN_ORIGINS.each do |origin|
    test "r_#{origin}에서 로그인 페이지에 접속할 수 있다" do
      visit "#{origin}/session/new"

      assert_current_path "#{origin}/session/new", url: true, wait: 4
      assert_selector "h1", exact_text: "Say One Thing", wait: 4
    end
  end
end
