require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "redirects to new_session_path when accessing rooms_path while unauthenticated" do
    get rooms_path
    assert_redirected_to new_session_path
  end

  test "redirects to new_session_path when accessing settings_path while unauthenticated" do
    get settings_path
    assert_redirected_to new_session_path
  end

  test "does not redirect to new_session_path when accessing new_session_path while unauthenticated" do
    get new_session_path
    assert_response :success
  end
end
