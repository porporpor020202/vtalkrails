require "test_helper"

class VoiceMessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @sender = users(:one)
    @recipient = User.create!(
      email_address: "active-listener@example.com",
      password: "password",
      last_active_at: Time.current
    )
    sign_in_as @sender
  end

  test "creates a random voice drop and room" do
    assert_difference [ "Room.count", "VoiceMessage.count" ], 1 do
      post voice_drop_path, params: {
        voice_message: {
          audio: fixture_file_upload("sample.webm", "audio/webm"),
          duration_ms: 3_500
        }
      }, as: :multipart
    end

    assert_response :created
    assert_equal @sender, VoiceMessage.last.sender
    assert VoiceMessage.last.audio.attached?
  end

  test "allows only the participant whose turn it is to reply" do
    room = Room.create!(
      user: @sender,
      opponent: @recipient,
      last_sender: @recipient,
      last_message_at: Time.current
    )

    assert_difference "VoiceMessage.count", 1 do
      post room_voice_messages_path(room), params: {
        voice_message: {
          audio: fixture_file_upload("sample.webm", "audio/webm"),
          duration_ms: 2_000
        }
      }, as: :multipart
    end

    assert_response :created
    assert_equal @sender, room.reload.last_sender

    assert_no_difference "VoiceMessage.count" do
      post room_voice_messages_path(room), params: {
        voice_message: {
          audio: fixture_file_upload("sample.webm", "audio/webm"),
          duration_ms: 2_000
        }
      }, as: :multipart
    end

    assert_response :unprocessable_entity
  end

  test "does not allow a stranger to post in a room" do
    stranger = User.create!(email_address: "stranger@example.com", password: "password")
    room = Room.create!(user: @recipient, opponent: stranger, last_sender: stranger)

    post room_voice_messages_path(room), params: {
      voice_message: {
        audio: fixture_file_upload("sample.webm", "audio/webm"),
        duration_ms: 2_000
      }
    }, as: :multipart

    assert_response :not_found
  end

  test "renders the rooms list and a voice conversation" do
    room = Room.create!(
      user: @sender,
      opponent: @recipient,
      last_sender: @recipient,
      last_message_at: Time.current
    )
    message = room.voice_messages.build(sender: @recipient, duration_ms: 2_000)
    message.audio.attach(fixture_file_upload("sample.webm", "audio/webm"))
    message.save!

    get rooms_path

    assert_response :success
    assert_select "button", text: /Drop a voice/
    assert_select "a[href='#{room_path(room)}']"

    get room_path(room)

    assert_response :success
    assert_select "audio[src]", count: 1
    assert_select "button", text: /Reply with voice/
  end
end
