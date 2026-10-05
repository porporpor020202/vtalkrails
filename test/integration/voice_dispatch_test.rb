require "test_helper"
require_relative "../test_helpers/voice_test_helper"

class VoiceDispatchTest < ActionDispatch::IntegrationTest
  include VoiceTestHelper

  setup do
    @sender = users(:english_native)
    @room_language = languages(:korean)
    @recipients = [ users(:korean_native), users(:spanish_native) ]
    @recipients.each do |user|
      user.update!(native_language: languages(:korean), learning_language: languages(:english), last_active_at: Time.current)
    end
    @outsider = users(:japanese_native)
    @outsider.update!(last_active_at: Time.current)
    sign_in_as(@sender)
  end

  test "r_녹음을 전송하면 선정된 수신자마다 새 룸을 생성한다" do
    previous_ids = Room.pluck(:id)

    assert_difference "Room.count", @recipients.size do
      post_recording
      assert_response :created
    end

    rooms = Room.where.not(id: previous_ids)
    assert_equal @recipients.map(&:id).sort, rooms.pluck(:opponent_id).sort
    assert_equal [ @sender.id ], rooms.distinct.pluck(:host_id)
    assert_equal [ @room_language.id ], rooms.distinct.pluck(:language_id)
    assert_equal @recipients.size, response.parsed_body.fetch("recipient_count")
  end

  test "r_생성된 각 룸에 발신자가 전송한 녹음을 연결한다" do
    post_recording
    assert_response :created

    @recipients.each do |recipient|
      room = Room.where(host: @sender, opponent: recipient, language: @room_language).sole
      message = room.voice_messages.sole

      assert_equal @sender, message.sender
      assert_equal 2_000, message.duration_ms
      assert message.audio.attached?
      assert_equal voice_audio, message.audio.download
    end
  end

  test "r_선정되지 않은 사용자에게는 룸과 메시지를 만들지 않는다" do
    post_recording
    assert_response :created

    assert_equal @recipients.map(&:id).sort, Room.where(host: @sender).pluck(:opponent_id).sort
    assert_equal @recipients.size, VoiceMessage.count
    assert_empty Room.involving(@outsider)
    assert_empty VoiceMessage.where(room_id: Room.involving(@outsider).select(:id))
  end

  test "r_같은 전송 요청을 여러 번 받아도 한 번만 전달한다" do
    request_key = SecureRandom.uuid

    assert_difference [ "VoiceDrop.count" ], 1 do
      assert_difference [ "Room.count", "VoiceMessage.count" ], @recipients.size do
        post_recording(request_key: request_key)
        assert_response :created
      end
    end

    first_result = response.parsed_body
    first_room_ids = Room.order(:id).pluck(:id)
    first_message_ids = VoiceMessage.order(:id).pluck(:id)

    assert_no_difference [ "VoiceDrop.count", "Room.count", "VoiceMessage.count" ] do
      post_recording(request_key: request_key)
      assert_response :created
    end

    assert_equal first_result, response.parsed_body
    assert_equal first_room_ids, Room.order(:id).pluck(:id)
    assert_equal first_message_ids, VoiceMessage.order(:id).pluck(:id)
  end

  test "r_전송 처리 도중 실패하면 일부 수신자에게만 전달된 상태로 남지 않는다" do
    existing_room = Room.create!(host: @sender, opponent: @outsider, language: languages(:english))
    existing_message = create_voice_message(room: existing_room, sender: @sender)
    created_messages = 0
    rooms_saved_before_failure = nil
    sender = @sender
    room_language = @room_language
    fail_second_message = proc do |message|
      created_messages += 1
      if created_messages == 2
        rooms_saved_before_failure = Room.where(host: sender, language: room_language).count
        message.errors.add(:base, "Test storage failure")
        raise ActiveRecord::RecordInvalid.new(message)
      end
    end

    VoiceMessage.set_callback(:create, :before, fail_second_message)
    begin
      assert_no_difference [ "VoiceDrop.count", "Room.count", "VoiceMessage.count" ] do
        post_recording
        assert_response :unprocessable_entity
      end
    ensure
      VoiceMessage.skip_callback(:create, :before, fail_second_message)
    end

    assert_equal 2, created_messages
    assert_operator rooms_saved_before_failure, :>=, 1
    assert_empty Room.where(host: @sender, language: @room_language)
    assert_equal existing_room.id, existing_message.reload.room_id
    assert_equal voice_audio, existing_message.audio.download
  end

  test "r_수신 후보가 없으면 안내를 반환하고 룸과 메시지를 만들지 않는다" do
    @recipients.each { |user| user.update!(last_active_at: nil) }

    assert_no_difference [ "VoiceDrop.count", "Room.count", "VoiceMessage.count" ] do
      post_recording
      assert_response :unprocessable_entity
    end

    assert_equal "No recipients are available right now. Please try again later.", response.parsed_body.fetch("error")
  end

  private

  def post_recording(request_key: SecureRandom.uuid)
    post voice_drop_path, params: {
      room_language_id: @room_language.id,
      request_key: request_key,
      voice_message: { audio: voice_upload, duration_ms: 2_000 }
    }, headers: { "Accept" => "application/json" }
  end
end
