require "test_helper"

class AccountManagementTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: "account-test@example.com",
      oauth_provider: :google,
      oauth_uid: "account-test-google-uid"
    )
    @token = @user.signed_id(purpose: :native_auth, expires_in: 5.minutes)
  end

  test "sign out ends the session and returns to the sign in screen" do
    get authenticate_by_token_google_oauth_sessions_path, params: { token: @token }

    delete session_path

    assert_redirected_to new_session_path
    get rooms_path
    assert_redirected_to new_session_path
  end

  test "delete account removes the user and associated rooms" do
    Room.create!(user: users(:one), opponent: @user)
    get authenticate_by_token_google_oauth_sessions_path, params: { token: @token }

    assert_difference("User.count", -1) do
      assert_difference("Room.count", -1) do
        delete account_path
      end
    end

    assert_redirected_to new_session_path
    assert_nil User.find_by(id: @user.id)
  end
end
