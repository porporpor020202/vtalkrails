require "test_helper"
require_relative "../test_helpers/apple_oauth_test_config"

class AppleOauthClient
  class << self
    attr_accessor :mocked_mode_enabled
  end

  alias_method :original_decode_native_id_token, :decode_native_id_token
  alias_method :original_authenticate, :authenticate

  def authenticate(code:, redirect_uri:, nonce:)
    return mocked_result if self.class.mocked_mode_enabled

    original_authenticate(code: code, redirect_uri: redirect_uri, nonce: nonce)
  end

  def decode_native_id_token(id_token, nonce:)
    if self.class.mocked_mode_enabled
      return { "sub" => mocked_result[:uid], "email" => mocked_result[:email] }
    end

    original_decode_native_id_token(id_token, nonce: nonce)
  end

  private

  def mocked_result
    {
      uid: "apple-test-user",
      email: "apple-test@example.com"
    }
  end
end

class AppleOauthSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    AppleOauthClient.mocked_mode_enabled = false
  end

  teardown do
    AppleOauthClient.mocked_mode_enabled = false
  end

  # --- Web Platform Flow ---

  AppleOauthTestConfig::APPLE_LOGIN_ORIGINS.each do |origin|
    test "r_#{origin}에 따른 올바른 Apple 인증 요청을 만든다" do
      uri = URI.parse(origin)
      host! uri.authority
      https! uri.scheme == "https"

      post apple_oauth_sessions_path, params: { platform: "web" }

      assert_response :redirect

      authorization_url = URI.parse(response.location)
      assert_equal "https", authorization_url.scheme
      assert_equal "appleid.apple.com", authorization_url.host
      assert_equal "/auth/authorize", authorization_url.path

      query = URI.decode_www_form(authorization_url.query).to_h
      assert_equal "#{origin}/apple_oauth_sessions/callback", query["redirect_uri"]
      assert_equal "email name", query["scope"]
      assert_equal "code", query["response_type"]
      assert_equal "form_post", query["response_mode"]
      assert_equal "web", query["state"].split(":").last
      stored_nonce = request.cookie_jar.encrypted[:apple_oauth_nonce]
      assert stored_nonce.present?
      assert_equal stored_nonce, query["nonce"]

      oauth_cookies = response.headers["Set-Cookie"].to_s
      assert_match(/samesite=none/i, oauth_cookies)
      assert_match(/secure/i, oauth_cookies)
    end
  end

  test "r_cancelled Apple sign in does not create a session" do
    post apple_oauth_sessions_path, params: { platform: "web" }
    state = URI.decode_www_form(URI.parse(response.location).query).to_h["state"]
    assert_no_difference "Session.count" do
      post callback_apple_oauth_sessions_path, params: { error: "user_cancelled_authorize", state: state }
    end
    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "r_callback without a saved state is rejected" do
    post callback_apple_oauth_sessions_path, params: { code: "dummy_code", state: "unsolicited" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "r_apple sign_in success redirects to root_path for web" do
    post apple_oauth_sessions_path, params: { platform: "web" }
    assert_redirected_to %r{https://appleid.apple.com/auth/authorize}

    authorization_url = URI.parse(response.location)
    query = URI.decode_www_form(authorization_url.query).to_h
    state = query["state"]
    assert_not_nil state

    AppleOauthClient.mocked_mode_enabled = true

    post callback_apple_oauth_sessions_path, params: { code: "dummy_code", state: state }

    assert_redirected_to root_path
    assert cookies[:session_id].present?
  end

  test "r_비로그인 상태에서 보호된 페이지 접근 후 Apple 로그인 성공 시 원래 요청 페이지로 리다이렉트된다" do
    get confirm_account_deletion_path
    assert_redirected_to new_session_path

    post apple_oauth_sessions_path, params: { platform: "web" }
    authorization_url = URI.parse(response.location)
    state = URI.decode_www_form(authorization_url.query).to_h["state"]
    AppleOauthClient.mocked_mode_enabled = true

    post callback_apple_oauth_sessions_path, params: { code: "dummy_code", state: state }

    assert_redirected_to confirm_account_deletion_path
  end

  # -------------------------------------------------
  # 1. iOS 네이티브 흐름 (identity_token -> token 발급)
  # -------------------------------------------------

  test "native_authenticate: 유효한 identity_token으로 기존 유저를 찾아 token을 발급한다" do
    @user.update!(oauth_provider: :apple, oauth_uid: "apple-test-user", email_address: "apple-test@example.com")

    AppleOauthClient.mocked_mode_enabled = true

    assert_no_difference "User.count" do
      post native_authenticate_apple_oauth_sessions_path,
        params: { identity_token: "dummy.jwt.token", nonce: "test-nonce" }.to_json,
        headers: { "Content-Type" => "application/json" }
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert json["token"].present?, "token이 응답에 포함되어야 한다"
  end

  test "native_authenticate: 유효한 identity_token으로 새 유저를 생성하고 token을 발급한다" do
    AppleOauthClient.mocked_mode_enabled = true

    assert_difference "User.count", 1 do
      post native_authenticate_apple_oauth_sessions_path,
        params: { identity_token: "dummy.jwt.token", nonce: "test-nonce" }.to_json,
        headers: { "Content-Type" => "application/json" }
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert json["token"].present?, "token이 응답에 포함되어야 한다"
    assert User.find_by(oauth_provider: :apple, oauth_uid: "apple-test-user").present?, "새 유저가 DB에 생성되어야 한다"
  end

  test "native_authenticate: identity_token이 없으면 bad_request를 반환한다" do
    post native_authenticate_apple_oauth_sessions_path,
      params: {}.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_equal "Missing identity token or nonce", json["error"]
  end

  # -------------------------------------------------
  # 2. 웹/안드로이드 흐름 (Apple OAuth PKCE)
  # -------------------------------------------------

  test "create: Apple 인증 URL로 리다이렉트된다" do
    post apple_oauth_sessions_path, params: { platform: "web" }

    assert_response :redirect
    assert_redirected_to %r{https://appleid.apple.com/auth/authorize}
  end

  test "create: 리다이렉트 URL에 state 파라미터가 포함된다" do
    post apple_oauth_sessions_path, params: { platform: "web" }

    assert_response :redirect
    assert response.location.include?("state="), "리다이렉트 URL에 state 파라미터가 있어야 한다"
  end

  test "callback: 네이티브 플랫폼 로그인 성공 시 커스텀 스킴으로 리다이렉트된다" do
    post apple_oauth_sessions_path, params: { platform: "native" }
    state_from_url = URI.decode_www_form(URI.parse(response.location).query).to_h["state"]

    AppleOauthClient.mocked_mode_enabled = true

    post callback_apple_oauth_sessions_path, params: { code: "dummy_code", state: state_from_url }

    assert_response :redirect
    assert_redirected_to %r{vtalk://auth-callback\?token=.+&platform=native}
  end

  test "callback: 잘못된 state로 요청 시 로그인 페이지로 리다이렉트된다" do
    post apple_oauth_sessions_path, params: { platform: "web" }

    post callback_apple_oauth_sessions_path, params: { code: "dummy_code", state: "invalid_state" }

    assert_redirected_to new_session_path
  end

  # -------------------------------------------------
  # 3. authenticate_by_token (토큰으로 세션 생성)
  # -------------------------------------------------

  test "authenticate_by_token: 유효한 token으로 로그인하고 root로 리다이렉트된다" do
    @user.update!(oauth_provider: :apple, oauth_uid: "apple-uid-token-test")
    token = @user.signed_id(purpose: :native_auth, expires_in: 5.minutes)

    get authenticate_by_token_apple_oauth_sessions_path, params: { token: token }

    assert_redirected_to root_path
    assert cookies[:session_id].present?, "세션 쿠키가 설정되어야 한다"
  end

  test "authenticate_by_token: 만료되거나 잘못된 token이면 로그인 페이지로 리다이렉트된다" do
    get authenticate_by_token_apple_oauth_sessions_path, params: { token: "invalid-token" }

    assert_redirected_to new_session_path
  end
end
