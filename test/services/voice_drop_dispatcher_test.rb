require "test_helper"
require "minitest/mock"

class VoiceDropDispatcherTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @sender = users(:korean_native)
    @english = languages(:english)
    @korean = languages(:korean)
  end

  test "sends to twenty distinct listeners regardless of native language with a single audio blob" do
    24.times { |i| listener("listener-#{i}", native_language: i.even? ? @english : @korean) }
    assert_difference("ActiveStorage::Blob.count", 1) do
      assert_difference(["Room.count", "VoiceMessage.count", "VoiceDelivery.count"], 20) do
        @drop = send_drop
      end
    end
    assert_equal 20, @drop.recipient_count
    assert_equal 20, @drop.voice_deliveries.distinct.count(:recipient_id)
    blob_ids = ActiveStorage::Attachment.where(record: VoiceMessage.where(room: @drop.rooms)).pluck(:blob_id)
    assert_equal 1, blob_ids.uniq.size
  end

  test "retries do not send another batch even after rooms are deleted" do
    key = SecureRandom.uuid
    drop = send_drop(request_key: key)
    drop.rooms.destroy_all
    assert_no_difference(["VoiceDrop.count", "Room.count", "ActiveStorage::Blob.count"]) do
      assert_equal drop.id, send_drop(request_key: key).id
    end
  end

  test "filters blocks incomplete users busy recipients and existing conversations" do
    blocked = listener("blocked")
    reverse = listener("reverse")
    UserBlock.create!(blocker: @sender, blocked: blocked)
    UserBlock.create!(blocker: reverse, blocked: @sender)
    incomplete = listener("incomplete")
    incomplete.update!(native_language: nil)
    unrelated_language = Language.create!(code: "fr", name: "French")
    unrelated = listener("unrelated")
    unrelated.update!(native_language: unrelated_language)
    existing = listener("existing")
    Room.create!(user: @sender, opponent: existing)
    busy = listener("busy")
    3.times { Room.create!(user: @sender, opponent: busy, last_sender: @sender) }
    other_language = listener("other-language")
    Room.create!(user: @sender, opponent: other_language)
    drop = send_drop
    ids = drop.voice_deliveries.pluck(:recipient_id)
    assert_includes ids, unrelated.id
    [@sender, blocked, reverse, incomplete, existing, busy, other_language].each { |user| assert_not_includes ids, user.id }
    assert_equal 2, drop.recipient_count
  end

  test "invalid audio duration rolls back the entire batch" do
    assert_no_difference(["VoiceDrop.count", "Room.count", "VoiceMessage.count", "ActiveStorage::Blob.count"]) do
      assert_raises(ActiveRecord::RecordInvalid) { send_drop(duration_ms: 31_000) }
    end
  end

  test "no recipients creates no batch or blob" do
    UserBlock.create!(blocker: @sender, blocked: users(:english_native))
    assert_no_difference(["VoiceDrop.count", "Room.count", "ActiveStorage::Blob.count"]) do
      assert_raises(VoiceDropDispatcher::NoRecipientAvailable) { send_drop }
    end
  end

  test "deleting one room preserves shared audio and deleting the last removes it" do
    listener("extra")
    drop = send_drop
    rooms = drop.rooms.order(:id).to_a
    blob = rooms.first.voice_messages.first.audio.blob
    assert blob.service.exist?(blob.key)
    perform_enqueued_jobs { rooms.first.destroy! }
    assert blob.reload.service.exist?(blob.key)
    assert rooms.last.voice_messages.first.audio.download.present?
    perform_enqueued_jobs { rooms.last.destroy! }
    assert_not ActiveStorage::Blob.exists?(blob.id)
    assert_not blob.service.exist?(blob.key)
  end

  test "first recipient reply is recorded once and survives room deletion" do
    drop = send_drop
    delivery = drop.voice_deliveries.first
    room = delivery.room
    2.times do
      room.voice_messages.create!(sender: delivery.recipient, duration_ms: 1000, audio: audio_upload)
    end
    assert_equal room.voice_messages.where(sender: delivery.recipient).minimum(:created_at), delivery.reload.first_replied_at
    room.destroy!
    assert_nil delivery.reload.room_id
    assert delivery.first_replied_at
  end

  test "a failure partway through fanout leaves no partial delivery or uploaded blob" do
    listener("rollback-extra")
    original = Room.method(:create!)
    calls = 0
    fail_second = ->(**attributes) do
      calls += 1
      raise "simulated storage or persistence failure" if calls == 2
      original.call(**attributes)
    end
    assert_no_difference(["VoiceDrop.count", "VoiceDelivery.count", "Room.count", "VoiceMessage.count", "ActiveStorage::Blob.count"]) do
      Room.stub(:create!, fail_second) do
        assert_raises(RuntimeError) { send_drop }
      end
    end
  end

  private

  def listener(name, native_language: @korean)
    User.create!(email_address: "#{name}@example.com", oauth_provider: :google, oauth_uid: name,
      native_language: native_language,
      last_active_at: Time.current)
  end

  def send_drop(request_key: SecureRandom.uuid, duration_ms: 1000)
    VoiceDropDispatcher.new(@sender).call(audio: audio_upload, duration_ms: duration_ms, request_key: request_key)
  end

  def audio_upload
    { io: StringIO.new("voice-message"), filename: "voice.webm", content_type: "audio/webm" }
  end
end
