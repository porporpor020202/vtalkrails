require "test_helper"

class VoiceFanoutTest < ActionDispatch::IntegrationTest
  test "both tabs deliver to the matching recipient language and retries keep the same count" do
    sender = users(:one)
    recipient = users(:two)
    sign_in_as sender
    { "mother" => languages(:korean), "learning" => languages(:english) }.each do |tab, language|
      key = SecureRandom.uuid
      attributes = -> { { request_key: key, voice_message: {
        audio: fixture_file_upload("sample.webm", "audio/webm"), duration_ms: 1000
      } } }
      post voice_drop_path(tab: tab), params: attributes.call
      assert_response :created
      drop = VoiceDrop.find(response.parsed_body.fetch("drop_id"))
      room = drop.rooms.first
      assert_equal language.id, room.language_id
      assert_equal 1, response.parsed_body.fetch("recipient_count")
      assert_equal rooms_path(tab: tab), response.parsed_body.fetch("redirect_url")
      assert_no_difference(["Room.count", "VoiceMessage.count", "VoiceDrop.count"]) do
        post voice_drop_path(tab: tab), params: attributes.call
      end
      assert_response :created
      sign_out
      sign_in_as recipient
      recipient_tab = recipient.mother_language_id == language.id ? "mother" : "learning"
      get rooms_path(tab: recipient_tab)
      assert_select "a[href='#{room_path(room, tab: recipient_tab)}']"
      opposite = recipient_tab == "mother" ? "learning" : "mother"
      get rooms_path(tab: opposite)
      assert_select "a[href^='#{room_path(room)}']", count: 0
      sign_out
      sign_in_as sender
    end
  end

  test "missing request key cannot create a transmission" do
    sign_in_as users(:one)
    assert_no_difference("VoiceDrop.count") do
      post voice_drop_path(tab: "learning"), params: { voice_message: {
        audio: fixture_file_upload("sample.webm", "audio/webm"), duration_ms: 1000
      } }
    end
    assert_response :bad_request
  end

  test "deleting a broadcast room keeps audio in another recipients room" do
    sender = users(:one)
    extra = User.create!(oauth_provider: :google, oauth_uid: "fanout-extra", email_address: "extra@example.com",
      mother_language: languages(:korean), learning_language: languages(:english))
    sign_in_as sender
    post voice_drop_path(tab: "learning"), params: { request_key: SecureRandom.uuid, voice_message: {
      audio: fixture_file_upload("sample.webm", "audio/webm"), duration_ms: 1000
    } }
    assert_response :created
    rooms = VoiceDrop.find(response.parsed_body["drop_id"]).rooms.order(:id).to_a
    assert_equal 2, rooms.size
    blob = rooms.last.voice_messages.first.audio.blob
    perform_enqueued_jobs { delete room_path(rooms.first, tab: "learning") }
    assert rooms.first.reload.deleted?
    assert rooms.last.voice_messages.first.audio.download.present?
    assert ActiveStorage::Blob.exists?(blob.id)
  end
end
