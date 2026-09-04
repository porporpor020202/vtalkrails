require "test_helper"

# Apple의 실제 JWT 검증을 우회하기 위해 네이티브 토큰 검증을 목(mock)으로 교체
class AppleOauthClient
  class << self
    attr_accessor :mocked_user_info
  end

  alias_method :original_decode_native_id_token, :decode_native_id_token
  alias_method :original_authenticate, :authenticate

  def decode_native_id_token(id_token, nonce:)
    if AppleOauthClient.mocked_user_info
      AppleOauthClient.mocked_user_info
    else
      original_decode_native_id_token(id_token, nonce: nonce)
    end
  end
end

class AppleOauthSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    AppleOauthClient.mocked_user_info = nil
  end

  teardown do
    AppleOauthClient.mocked_user_info = nil
    AppleOauthClient.alias_method :authenticate, :original_authenticate
  end

  test "Apple browser authorization defaults to web and uses an HTTPS form POST callback" do
    https!
    host! "vtalks.net"
    post apple_oauth_sessions_path

    query = URI.decode_www_form(URI.parse(response.location).query).to_h
    assert_equal "web", query["state"].split(":").last
    assert_equal "https://vtalks.net/apple_oauth_sessions/callback", query["redirect_uri"]
    assert_equal "form_post", query["response_mode"]
    assert query["nonce"].present?
    oauth_cookies = response.headers["Set-Cookie"].to_s
    assert_match(/samesite=none/i, oauth_cookies)
    assert_match(/secure/i, oauth_cookies)
  end

  test "cancelled Apple sign in does not create a session" do
    post apple_oauth_sessions_path, params: { platform: "web" }
    state = URI.decode_www_form(URI.parse(response.location).query).to_h["state"]
    assert_no_difference "Session.count" do
      post callback_apple_oauth_sessions_path, params: { error: "user_cancelled_authorize", state: state }
    end
    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  # -------------------------------------------------
  # 1. iOS 네이티브 흐름 (identity_token -> token 발급)
  # -------------------------------------------------

  test "native_authenticate: 유효한 identity_token으로 기존 유저를 찾아 token을 발급한다" do
    @user.update!(oauth_provider: :apple, oauth_uid: "apple-uid-123")

    AppleOauthClient.mocked_user_info = { "sub" => "apple-uid-123", "email" => @user.email_address }

    post native_authenticate_apple_oauth_sessions_path,
      params: { identity_token: "dummy.jwt.token", nonce: "test-nonce" }.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :success
    json = JSON.parse(response.body)
    assert json["token"].present?, "token이 응답에 포함되어야 한다"
  end

  test "native_authenticate: 유효한 identity_token으로 새 유저를 생성하고 token을 발급한다" do
    AppleOauthClient.mocked_user_info = { "sub" => "apple-new-uid-999", "email" => "newapple@example.com" }

    post native_authenticate_apple_oauth_sessions_path,
      params: { identity_token: "dummy.jwt.token", nonce: "test-nonce" }.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :success
    json = JSON.parse(response.body)
    assert json["token"].present?, "token이 응답에 포함되어야 한다"
    assert User.find_by(oauth_uid: "apple-new-uid-999").present?, "새 유저가 DB에 생성되어야 한다"
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

  test "callback: 웹 플랫폼 로그인 성공 시 root로 리다이렉트된다" do
    @user.update!(oauth_provider: :apple, oauth_uid: "apple-web-uid-456")
    user_uid   = "apple-web-uid-456"
    user_email = @user.email_address

    # create로 session에 state/nonce 세팅 및 리다이렉트 URL에서 state 추출
    post apple_oauth_sessions_path, params: { platform: "web" }
    state_from_url = URI.decode_www_form(URI.parse(response.location).query).to_h["state"]

    # Apple 서버 인증을 목(mock)으로 교체 (로카로 변수로 uid/email 캐시)
    AppleOauthClient.define_method(:authenticate) do |code:, redirect_uri:, nonce:|
      { uid: user_uid, email: user_email }
    end

    post callback_apple_oauth_sessions_path, params: { code: "dummy_code", state: state_from_url }

    assert_redirected_to root_path
    assert cookies[:session_id].present?, "세션 쿠키가 설정되어야 한다"
  ensure
    AppleOauthClient.remove_method(:authenticate) rescue nil
  end

  test "callback: 계정 삭제 인증 후 확인 화면으로 돌아간다" do
    @user.update!(oauth_provider: :apple, oauth_uid: "apple-deletion-uid")
    user_uid = "apple-deletion-uid"
    user_email = @user.email_address

    get confirm_account_deletion_path
    assert_redirected_to new_session_path
    post apple_oauth_sessions_path, params: { platform: "web" }
    state_from_url = URI.decode_www_form(URI.parse(response.location).query).to_h["state"]

    AppleOauthClient.define_method(:authenticate) do |code:, redirect_uri:, nonce:|
      { uid: user_uid, email: user_email }
    end

    post callback_apple_oauth_sessions_path, params: { code: "dummy_code", state: state_from_url }

    assert_redirected_to confirm_account_deletion_path
  ensure
    AppleOauthClient.remove_method(:authenticate) rescue nil
  end

  test "callback: 네이티브 플랫폼 로그인 성공 시 커스텀 스킴으로 리다이렉트된다" do
    @user.update!(oauth_provider: :apple, oauth_uid: "apple-native-uid-789")
    user_uid   = "apple-native-uid-789"
    user_email = @user.email_address

    post apple_oauth_sessions_path, params: { platform: "native" }
    state_from_url = URI.decode_www_form(URI.parse(response.location).query).to_h["state"]

    AppleOauthClient.define_method(:authenticate) do |code:, redirect_uri:, nonce:|
      { uid: user_uid, email: user_email }
    end

    post callback_apple_oauth_sessions_path, params: { code: "dummy_code", state: state_from_url }

    assert_response :redirect
    assert_redirected_to %r{vtalk://auth-callback\?token=.+&platform=native}
  ensure
    AppleOauthClient.remove_method(:authenticate) rescue nil
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
