require "test_helper"

class VoiceDropDispatcherTest < ActiveSupport::TestCase
  setup do
    User.update_all(guest: true)
    @sender = create_user("sender@example.com", last_active_at: Time.current)
  end

  test "delivers a voice message to a recently active user" do
    recipient = create_user("listener@example.com", last_active_at: 10.minutes.ago)

    room = VoiceDropDispatcher.new(@sender).call(audio: audio_upload, duration_ms: 4_000)

    assert_equal recipient, room.opponent_for(@sender)
    assert_equal @sender, room.last_sender
    assert_equal 1, room.voice_messages.count
    assert room.voice_messages.first.audio.attached?
  end

  test "delivers to an inactive registered user during store review" do
    recipient = create_user("inactive@example.com", last_active_at: 8.days.ago)

    # Previous production behavior while the 7-day activity filter was enabled:
    # assert_raises VoiceDropDispatcher::NoRecipientAvailable do
    #   VoiceDropDispatcher.new(@sender).call(audio: audio_upload, duration_ms: 4_000)
    # end
    room = VoiceDropDispatcher.new(@sender).call(audio: audio_upload, duration_ms: 4_000)

    assert_equal recipient, room.opponent_for(@sender)
  end

  test "does not create a second room for an existing pair" do
    existing = create_user("existing@example.com", last_active_at: 5.minutes.ago)
    available = create_user("available@example.com", last_active_at: 20.minutes.ago)
    Room.create!(user: @sender, opponent: existing)

    room = VoiceDropDispatcher.new(@sender).call(audio: audio_upload, duration_ms: 4_000)

    assert_equal available, room.opponent_for(@sender)
  end

  test "can start a new voice drop after a previous room was deleted" do
    recipient = create_user("former-partner@example.com", last_active_at: 5.minutes.ago)
    Room.create!(
      user: @sender,
      opponent: recipient,
      status: :deleted,
      deleted_by: recipient
    )

    room = VoiceDropDispatcher.new(@sender).call(audio: audio_upload, duration_ms: 4_000)

    assert_equal recipient, room.opponent_for(@sender)
    assert_equal 2, Room.between(@sender, recipient).count
  end

  test "does not match users when either user has blocked the other" do
    blocked_by_sender = create_user("blocked-by-sender@example.com", last_active_at: 2.minutes.ago)
    blocked_sender = create_user("blocked-sender@example.com", last_active_at: 3.minutes.ago)
    available = create_user("safe-listener@example.com", last_active_at: 10.minutes.ago)
    UserBlock.create!(blocker: @sender, blocked: blocked_by_sender)
    UserBlock.create!(blocker: blocked_sender, blocked: @sender)

    room = VoiceDropDispatcher.new(@sender).call(audio: audio_upload, duration_ms: 4_000)

    assert_equal available, room.opponent_for(@sender)
  end

  private

  def create_user(email, last_active_at:)
    User.create!(email_address: email, password: "password", last_active_at:)
  end

  def audio_upload
    {
      io: StringIO.new("voice-message"),
      filename: "voice.webm",
      content_type: "audio/webm"
    }
  end
end
