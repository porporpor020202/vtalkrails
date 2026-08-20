require "test_helper"

class GoogleOauthClient
  class << self
    attr_accessor :mocked_result
  end

  alias_method :original_authenticate, :authenticate
  alias_method :original_authenticate_id_token, :authenticate_id_token

  def authenticate(code:, redirect_uri:)
    if GoogleOauthClient.mocked_result
      GoogleOauthClient.mocked_result
    else
      original_authenticate(code: code, redirect_uri: redirect_uri)
    end
  end

  def authenticate_id_token(id_token, nonce:)
    if GoogleOauthClient.mocked_result
      GoogleOauthClient.mocked_result
    else
      original_authenticate_id_token(id_token, nonce: nonce)
    end
  end
end

class GoogleOauthSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    GoogleOauthClient.mocked_result = nil
  end

  teardown do
    GoogleOauthClient.mocked_result = nil
  end

  # --- Web Platform Flow ---

  test "google login success redirects to root_path for web" do
    post google_oauth_sessions_path, params: { platform: "web" }
    assert_redirected_to %r{https://accounts.google.com/o/oauth2/v2/auth}

    state = session[:google_oauth_state]
    assert_not_nil state

    GoogleOauthClient.mocked_result = { uid: "google-12345", email: @user.email_address }

    get callback_google_oauth_sessions_path, params: { code: "dummy_code", state: state }

    assert_redirected_to root_path
    assert cookies[:session_id].present?
  end

  test "google login returns to the protected account deletion confirmation" do
    get confirm_account_deletion_path
    assert_redirected_to new_session_path

    post google_oauth_sessions_path, params: { platform: "web" }
    state = session[:google_oauth_state]
    GoogleOauthClient.mocked_result = { uid: "google-12345", email: @user.email_address }

    get callback_google_oauth_sessions_path, params: { code: "dummy_code", state: state }

    assert_redirected_to confirm_account_deletion_path
  end

  # --- Native Platform Flow ---

  test "native Google identity token returns a short-lived session token" do
    GoogleOauthClient.mocked_result = { uid: "google-native-123", email: "native-google@example.com" }

    post native_authenticate_google_oauth_sessions_path,
      params: { identity_token: "dummy.jwt.token", nonce: "test-nonce" }.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :success
    assert JSON.parse(response.body)["token"].present?
  end

  test "google login success redirects to custom native scheme for native platform" do
    post google_oauth_sessions_path, params: { platform: "native" }
    assert_redirected_to %r{https://accounts.google.com/o/oauth2/v2/auth}

    state = session[:google_oauth_state]
    assert_not_nil state
    assert_equal "native", state.split(":").last

    GoogleOauthClient.mocked_result = { uid: "google-12345", email: @user.email_address }

    get callback_google_oauth_sessions_path, params: { code: "dummy_code", state: state }

    assert_response :redirect
    assert_redirected_to %r{vtalk://auth-callback\?token=.+&platform=native}
  end

  # --- Error & Validation Flow ---

  test "google login callback with invalid state redirects to login" do
    # Initiate session to set state
    post google_oauth_sessions_path, params: { platform: "web" }

    # Send callback with invalid state
    get callback_google_oauth_sessions_path, params: { code: "dummy_code", state: "invalid_state" }

    # This should fail. Let's see where it redirects or if it throws NameError.
    assert_redirected_to new_session_path
  end
end
