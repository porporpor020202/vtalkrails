require "test_helper"
require "minitest/mock"
require "uri"

class GoogleOauthCallbackTest < ActionDispatch::IntegrationTest
  setup do
    Current.reset
    patch native_language_path, params: { native_language: "ko" }
    DailyQuestion.create!(asked_on: Date.current, question: "What made you smile today?", source: "sample")
  end
  teardown { Current.reset }

  test "r_Google 콜백으로 신규 사용자를 생성하고 로그인한다-web" do
    uid = "google-test-#{SecureRandom.hex(8)}"
    email = "#{uid}@example.com"

    assert_difference "User.count", 1 do
      complete_google_callback(uid: uid, email: email)
    end

    user = User.find_by!(oauth_provider: "google", oauth_uid: uid)
    assert_equal email, user.email_address
    assert_equal 1, user.sessions.count
    assert cookies[:session_id].present?
    assert_redirected_to root_url
    follow_redirect!
    assert_response :success
    assert_select "#daily-question"
    assert_not User.column_names.include?("display_name")
  end

  test "returning users go directly to daily practice" do
    user = users(:korean_native)
    assert_no_difference "User.count" do
      complete_google_callback(uid: user.oauth_uid, email: user.email_address)
    end
    assert_redirected_to root_url
    follow_redirect!
    assert_response :success
    assert_select "#daily-question"
  end

  private

  def complete_google_callback(uid:, email:)
    post google_oauth_sessions_path, params: { platform: "web" }
    assert_response :redirect

    query = URI.decode_www_form(
      URI.parse(response.location).query
    ).to_h

    assert query.fetch("state").present?
    assert query.fetch("nonce").present?

    google_client = Minitest::Mock.new
    google_client.expect(
      :authenticate,
      { uid: uid, email: email },
      [],
      code: "test-authorization-code",
      redirect_uri: callback_google_oauth_sessions_url,
      nonce: query.fetch("nonce")
    )

    GoogleOauthClient.stub(:new, google_client) do
      get callback_google_oauth_sessions_path, params: {
        code: "test-authorization-code",
        state: query.fetch("state")
      }
    end

    google_client.verify
  end
end
