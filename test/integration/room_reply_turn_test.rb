require "test_helper"
require_relative "../test_helpers/voice_test_helper"

class RoomReplyTurnTest < ActionDispatch::IntegrationTest
  include VoiceTestHelper

  setup do
    @host = users(:english_native)
    @recipient = users(:korean_native)
    @room_language = languages(:korean)
    @room = Room.create!(host: @host, opponent: @recipient, language: @room_language)
    create_voice_message(room: @room, sender: @host)
  end

  test "호스트의 첫 메시지 이후 수신자는 한 번 답장할 수 있다" do
    sign_in_as(@recipient)

    assert_difference -> { @room.voice_messages.count }, 1 do
      post_reply
      assert_response :created
    end
    assert_equal @recipient, @room.voice_messages.order(:created_at, :id).last.sender
  end

  test "호스트는 수신자가 답하기 전에 연속으로 보낼 수 없다" do
    sign_in_as(@host)

    assert_no_difference [ "VoiceMessage.count", "ActiveStorage::Attachment.count" ] do
      post_reply
      assert_response :unprocessable_entity
    end
  end

  test "수신자는 답장한 후 직접 다시 요청해도 연속으로 보낼 수 없다" do
    sign_in_as(@recipient)
    post_reply
    assert_response :created

    assert_no_difference [ "VoiceMessage.count", "ActiveStorage::Attachment.count" ] do
      post_reply
      assert_response :unprocessable_entity
    end
  end

  test "상대방이 답장하면 다시 한 번 보낼 수 있고 차례는 룸별로 독립적이다" do
    other_room = Room.create!(host: @host, opponent: @recipient, language: @room_language)
    create_voice_message(room: other_room, sender: @host)
    create_voice_message(room: @room, sender: @recipient)
    sign_in_as(@host)
    post_reply
    assert_response :created
    sign_in_as(@recipient)

    assert_difference -> { @room.voice_messages.count }, 1 do
      post_reply
      assert_response :created
    end
    assert_difference -> { other_room.voice_messages.count }, 1 do
      post_reply(other_room)
      assert_response :created
    end
    assert_equal [ @host.id, @recipient.id, @host.id, @recipient.id ], @room.voice_messages.order(:created_at, :id).pluck(:sender_id)
  end

  private

  def post_reply(room = @room)
    post room_voice_messages_path(room), params: {
      voice_message: { audio: voice_upload, duration_ms: 2_000 }
    }, headers: { "Accept" => "application/json" }
  end
end
