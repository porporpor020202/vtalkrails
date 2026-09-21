require "test_helper"
require "minitest/mock"

class NativeGoogleVoiceConversationTest < ActionDispatch::IntegrationTest
  test "two Google accounts sign in, exchange audio and retain their nicknames" do
    User.destroy_all
    sender = open_session
    recipient = open_session
    sender_user = google_sign_in(sender, "voice-sender")
    recipient_user = google_sign_in(recipient, "voice-recipient")
    original_name = sender_user.display_name

    sender.post voice_drop_path, params: { voice_message: voice_upload }, as: :multipart
    assert_equal 201, sender.response.status
    room = Room.last
    assert_equal recipient_user, room.opponent_for(sender_user)

    recipient.get room_path(room)
    assert_equal 200, recipient.response.status
    assert_includes recipient.response.body, sender_user.display_name
    assert room.voice_messages.first.audio.download.present?

    recipient.post room_voice_messages_path(room), params: { voice_message: voice_upload }, as: :multipart
    assert_equal 201, recipient.response.status
    assert_equal recipient_user, room.reload.last_sender
    assert_equal 2, room.voice_messages.count

    sender.get room_path(room)
    assert_equal 200, sender.response.status
    assert_includes sender.response.body, recipient_user.display_name
    assert room.voice_messages.last.audio.download.present?

    sender.delete session_path
    assert_no_difference "User.count" do
      assert_equal sender_user.id, google_sign_in(sender, "voice-sender").id
    end
    assert_equal original_name, sender_user.reload.display_name
  end

  private

  def google_sign_in(browser, uid)
    verifier = Object.new
    verifier.define_singleton_method(:authenticate_id_token) do |_token, nonce:|
      raise "Unexpected nonce" unless nonce == "test-nonce"
      { uid: uid, email: "#{uid}@example.com" }
    end
    GoogleOauthClient.stub(:new, verifier) do
      browser.post native_authenticate_google_oauth_sessions_path,
        params: { identity_token: "verified-by-test-double", nonce: "test-nonce" }, as: :json
    end
    assert_equal 200, browser.response.status
    token = browser.response.parsed_body.fetch("token")
    browser.get authenticate_by_token_google_oauth_sessions_path, params: { token: token }
    assert_equal 302, browser.response.status
    browser.follow_redirect!
    assert_equal 200, browser.response.status
    User.find_by!(oauth_provider: :google, oauth_uid: uid)
  end

  def voice_upload
    { audio: fixture_file_upload("sample.webm", "audio/webm"), duration_ms: 2_000 }
  end
end
