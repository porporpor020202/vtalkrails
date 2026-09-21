require "application_system_test_case"

class SignInNavigationTest < ApplicationSystemTestCase
  test "r_sign-in 후 루트 화면에서 Rooms 탭이 선택된다" do
    token = users(:one).signed_id(purpose: :native_auth, expires_in: 5.minutes)
    visit authenticate_by_token_google_oauth_sessions_path(token: token)

    pp "user: #{users(:one)}"
    pp "token: #{token}"
    pp "user.fins_signed #{User.find_signed(token, purpose: :native_auth)}"

    assert_current_path root_path
    within "nav[aria-label='Primary navigation']" do
      assert_selector "a[href='#{rooms_path}'][aria-current='page'].text-indigo-600", text: "Rooms"
      assert_selector "a[aria-current='page']", count: 1
      assert_selector "a[href='#{mypage_path}']:not([aria-current]).text-slate-400", text: "My Page"
    end
  end
end


# 이 테스트는 검증 완료되었다.
