require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "redirects to new_session_path when accessing rooms_path while unauthenticated" do
    get rooms_path
    assert_redirected_to new_session_path
  end

  test "redirects to new_session_path when accessing mypage_path while unauthenticated" do
    get mypage_path
    assert_redirected_to new_session_path
  end

  test "does not redirect to new_session_path when accessing new_session_path while unauthenticated" do
    get new_session_path
    assert_response :success
    assert_select "button", text: /Continue with Google/
    assert_select "button", text: /Continue with Apple/
    assert_select "#bottom-tab-bar", count: 0
  end

  test "native app user agents receive native sign-in links" do
    get new_session_path, headers: { "User-Agent" => "Mozilla/5.0 VtalkiOS/1.0" }

    assert_response :success
    assert_select "a[href='vtalk://sign-in?provider=google']", text: /Continue with Google/
    assert_select "a[href='vtalk://sign-in?provider=apple']", text: /Continue with Apple/
    assert_select "form[action='#{google_oauth_sessions_path}']", count: 0
    assert_select "form[action='#{apple_oauth_sessions_path}']", count: 0
  end
end
