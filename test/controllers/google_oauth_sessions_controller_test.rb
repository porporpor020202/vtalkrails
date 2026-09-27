require "test_helper"
require "minitest/mock"
require_relative "../test_helpers/google_oauth_test_config"

class GoogleOauthClient
  class << self
    attr_accessor :mocked_mode_enabled
  end

  alias_method :original_authenticate, :authenticate
  alias_method :original_authenticate_id_token, :authenticate_id_token

  def authenticate(code:, redirect_uri:, nonce:)
    return mocked_result if self.class.mocked_mode_enabled

    original_authenticate(code: code, redirect_uri: redirect_uri, nonce: nonce)
  end

  def authenticate_id_token(id_token, nonce:)
    return mocked_result if self.class.mocked_mode_enabled

    original_authenticate_id_token(id_token, nonce: nonce)
  end

  private

  def mocked_result
    {
      uid: "google-test-user",
      email: "google-test@example.com"
    }
  end
end

class GoogleOauthSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    GoogleOauthClient.mocked_mode_enabled = false
  end

  teardown do
    GoogleOauthClient.mocked_mode_enabled = false
  end

  # --- Web Platform Flow ---

  GoogleOauthTestConfig::GOOGLE_LOGIN_ORIGINS.each do |origin|
    test "r_#{origin}에 따른 올바른 Google 인증 요청을 만든다" do
      uri = URI.parse(origin)
      host! uri.authority
      https! uri.scheme == "https"

      post google_oauth_sessions_path, params: { platform: "web" }

      assert_response :redirect

      authorization_url = URI.parse(response.location)
      assert_equal "https", authorization_url.scheme
      assert_equal "accounts.google.com", authorization_url.host

      query = URI.decode_www_form(authorization_url.query).to_h
      assert_equal "#{origin}/google_oauth_sessions/callback", query["redirect_uri"]
      assert_equal "openid email profile", query["scope"]
      assert_equal "code", query["response_type"]
      assert_equal "web", query["state"].split(":").last
      assert query["nonce"].present?
      assert_equal session[:google_oauth_nonce], query["nonce"]
    end
  end

  test "r_cancelled Google sign in does not create a session" do
    post google_oauth_sessions_path, params: { platform: "web" }
    state = session[:google_oauth_state]
    assert_no_difference "Session.count" do
      get callback_google_oauth_sessions_path, params: { error: "access_denied", state: state }
    end
    assert_redirected_to new_session_path
    assert_nil session[:google_oauth_state]
    assert_nil session[:google_oauth_nonce]
  end

  test "r_callback without a saved state is rejected" do
    get callback_google_oauth_sessions_path, params: { code: "dummy_code", state: "unsolicited" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "r_google sign_in success redirects to root_path for web" do
    post google_oauth_sessions_path, params: { platform: "web" }
    assert_redirected_to %r{https://accounts.google.com/o/oauth2/v2/auth}

    state = session[:google_oauth_state]
    assert_not_nil state

    GoogleOauthClient.mocked_mode_enabled = true

    get callback_google_oauth_sessions_path, params: { code: "dummy_code", state: state }

    assert_redirected_to root_path
    assert cookies[:session_id].present?
  end

  test "r_비로그인 상태에서 보호된 페이지 접근 후 Google 로그인 성공 시 원래 요청 페이지로 리다이렉트된다" do
    get confirm_account_deletion_path
    assert_redirected_to new_session_path

    post google_oauth_sessions_path, params: { platform: "web" }
    state = session[:google_oauth_state]
    GoogleOauthClient.mocked_mode_enabled = true

    get callback_google_oauth_sessions_path, params: { code: "dummy_code", state: state }

    assert_redirected_to confirm_account_deletion_path
  end

  test "web login generates a fresh nonce for each request" do
    post google_oauth_sessions_path, params: { platform: "web" }
    first_nonce = session[:google_oauth_nonce]
    assert first_nonce.present?

    post google_oauth_sessions_path, params: { platform: "web" }
    assert session[:google_oauth_nonce].present?
    assert_not_equal first_nonce, session[:google_oauth_nonce]
  end

  test "web callback passes the saved nonce to the client and consumes it" do
    post google_oauth_sessions_path, params: { platform: "web" }
    state = session[:google_oauth_state]
    nonce = session[:google_oauth_nonce]
    assert nonce.present?

    verifier = Minitest::Mock.new
    verifier.expect(:authenticate, { uid: "nonce-user", email: "nonce@example.com" }) do |**arguments|
      arguments == { code: "dummy_code", redirect_uri: callback_google_oauth_sessions_url, nonce: nonce }
    end

    GoogleOauthClient.stub(:new, verifier) do
      get callback_google_oauth_sessions_path, params: { code: "dummy_code", state: state }
    end

    verifier.verify
    assert_redirected_to root_path
    assert cookies[:session_id].present?
    assert_nil session[:google_oauth_nonce]
    assert_nil session[:google_oauth_state]

    assert_no_difference "Session.count" do
      get callback_google_oauth_sessions_path, params: { code: "dummy_code", state: state }
    end
    assert_redirected_to new_session_path
  end

  test "web callback rejects a missing saved nonce" do
    SecureRandom.stub(:urlsafe_base64, nil) do
      post google_oauth_sessions_path, params: { platform: "web" }
    end
    state = session[:google_oauth_state]
    GoogleOauthClient.mocked_mode_enabled = true

    assert_no_difference [ "User.count", "Session.count" ] do
      get callback_google_oauth_sessions_path, params: { code: "dummy_code", state: state }
    end

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
    assert_nil session[:google_oauth_state]
    assert_nil session[:google_oauth_nonce]
  end

  test "web callback consumes nonce when token authentication fails" do
    post google_oauth_sessions_path, params: { platform: "web" }
    state = session[:google_oauth_state]
    verifier = Object.new
    verifier.define_singleton_method(:authenticate) do |**|
      raise GoogleOauthClient::AuthenticationError, "Nonce verification failed"
    end

    GoogleOauthClient.stub(:new, verifier) do
      assert_no_difference "Session.count" do
        get callback_google_oauth_sessions_path, params: { code: "dummy_code", state: state }
      end
    end

    assert_redirected_to new_session_path
    assert_nil session[:google_oauth_nonce]
    assert_nil session[:google_oauth_state]
    assert_nil cookies[:session_id]
  end

  # --- Native Platform Flow ---

  test "native Google identity token returns a short-lived session token" do
    GoogleOauthClient.mocked_mode_enabled = true

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

    GoogleOauthClient.mocked_mode_enabled = true

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
    assert_nil session[:google_oauth_nonce]
  end
end
