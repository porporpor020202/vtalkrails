require "test_helper"
require_relative "../test_helpers/voice_test_helper"

class NativeLanguageRoomsTest < ActionDispatch::IntegrationTest
  include VoiceTestHelper

  setup do
    @user = users(:english_native)
    @partner = users(:korean_native)
    @partner.update!(native_language: @user.native_language, last_active_at: Time.current)
    @room = Room.create!(host: @partner, opponent: @user)
    @message = create_voice_message(room: @room, sender: @partner)
    @spanish_room = Room.create!(host: @partner, opponent: @user, native_language: languages(:spanish))
    @spanish_message = create_voice_message(room: @spanish_room, sender: @partner)
    sign_in_as(@user)
  end

  test "the index shows only rooms in the selected native language" do
    get rooms_path
    assert_response :success
    assert_select ".voice-inbox-header", text: /Language:.*English/
    assert_select "a[href=?]", room_path(@room), count: 1
    assert_select "a[href=?]", room_path(@spanish_room), count: 0

    @user.update!(native_language: languages(:spanish))
    get rooms_path
    assert_select ".voice-inbox-header", text: /Language:.*Spanish/
    assert_select "a[href=?]", room_path(@room), count: 0
    assert_select "a[href=?]", room_path(@spanish_room), count: 1
    assert_equal languages(:english), @room.reload.native_language
  end

  test "other language rooms cannot be read changed or used through direct URLs" do
    get room_path(@spanish_room)
    assert_response :not_found
    get audio_room_voice_message_path(@spanish_room, @spanish_message)
    assert_response :not_found
    get room_safety_path(@spanish_room)
    assert_response :not_found
    assert_no_difference ["VoiceMessage.count", "ContentReport.count", "UserBlock.count"] do
      post room_voice_messages_path(@spanish_room), params: { voice_message: { audio: voice_upload, duration_ms: 2000 } }
      assert_response :not_found
      post room_report_path(@spanish_room), params: { content_report: { reason: "harassment" } }
      assert_response :not_found
      post room_block_path(@spanish_room)
      assert_response :not_found
    end
    delete room_path(@spanish_room)
    assert_response :not_found
    assert @spanish_room.reload.active?
  end

  test "changing language revokes room and audio access until switching back" do
    get room_path(@room)
    assert_response :success
    @user.update!(native_language: languages(:spanish))
    get room_path(@room)
    assert_response :not_found
    get audio_room_voice_message_path(@room, @message)
    assert_response :not_found
    @user.update!(native_language: languages(:english))
    get room_path(@room)
    assert_response :success
  end

  test "a reply is not delivered to a partner who changed native language" do
    @partner.update!(native_language: languages(:spanish))
    assert_no_difference "VoiceMessage.count" do
      post room_voice_messages_path(@room), params: { voice_message: { audio: voice_upload, duration_ms: 2000 } }
      assert_response :unprocessable_entity
    end
  end

  test "recordings create rooms only for people using the same language" do
    outsider = users(:spanish_native)
    outsider.update!(last_active_at: Time.current)
    assert_difference "Room.count", 1 do
      post voice_drop_path, params: { request_key: SecureRandom.uuid, voice_message: { audio: voice_upload, duration_ms: 2000 } }
      assert_response :created
    end
    drop = @user.voice_drops.sole
    assert_equal @user.native_language, drop.native_language
    assert_equal [@partner.id], drop.rooms.pluck(:opponent_id)
    assert_equal [@user.native_language_id], drop.rooms.distinct.pluck(:native_language_id)
  end

  test "there is no fallback to other languages when no matching recipient is available" do
    @partner.update!(native_language: languages(:spanish))
    assert_no_difference ["Room.count", "VoiceMessage.count", "VoiceDrop.count"] do
      post voice_drop_path, params: { request_key: SecureRandom.uuid, voice_message: { audio: voice_upload, duration_ms: 2000 } }
      assert_response :unprocessable_entity
    end
  end
end
