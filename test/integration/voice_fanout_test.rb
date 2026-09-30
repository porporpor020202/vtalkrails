require "test_helper"

class VoiceFanoutTest < ActionDispatch::IntegrationTest
  test "Say delivers across native languages and retries keep the same batch" do
    sender = users(:korean_native)
    recipient = users(:english_native)
    sign_in_as sender
    key = SecureRandom.uuid
    attributes = -> { { request_key: key, voice_message: {
      audio: fixture_file_upload("sample.webm", "audio/webm"), duration_ms: 1000
    } } }
    post voice_drop_path, params: attributes.call
    assert_response :created
    room = VoiceDrop.find(response.parsed_body.fetch("drop_id")).rooms.first
    assert_equal 1, response.parsed_body.fetch("recipient_count")
    assert_equal rooms_path, response.parsed_body.fetch("redirect_url")
    assert_no_difference(["Room.count", "VoiceMessage.count", "VoiceDrop.count"]) do
      post voice_drop_path, params: attributes.call
    end
    assert_response :created
    sign_out
    sign_in_as recipient
    get rooms_path
    assert_select "a[href='#{room_path(room)}']"
  end

  test "missing request key cannot create a transmission" do
    sign_in_as users(:korean_native)
    assert_no_difference("VoiceDrop.count") do
      post voice_drop_path, params: { voice_message: {
        audio: fixture_file_upload("sample.webm", "audio/webm"), duration_ms: 1000
      } }
    end
    assert_response :bad_request
  end

  test "deleting a broadcast room keeps audio in another recipients room" do
    sender = users(:korean_native)
    extra = User.create!(oauth_provider: :google, oauth_uid: "fanout-extra", email_address: "extra@example.com",
      native_language: languages(:korean))
    sign_in_as sender
    post voice_drop_path, params: { request_key: SecureRandom.uuid, voice_message: {
      audio: fixture_file_upload("sample.webm", "audio/webm"), duration_ms: 1000
    } }
    assert_response :created
    rooms = VoiceDrop.find(response.parsed_body["drop_id"]).rooms.order(:id).to_a
    assert_equal 2, rooms.size
    blob = rooms.last.voice_messages.first.audio.blob
    perform_enqueued_jobs { delete room_path(rooms.first) }
    assert rooms.first.reload.deleted?
    assert rooms.last.voice_messages.first.audio.download.present?
    assert ActiveStorage::Blob.exists?(blob.id)
  end
end
