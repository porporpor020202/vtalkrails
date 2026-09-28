require "test_helper"

class ConcurrentDispatchTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @tag = SecureRandom.hex(6)
    @users = []
    @language = Language.find_by!(code: "en")
    @other = Language.find_by!(code: "ko")
  end

  teardown do
    @users.each { |user| user.destroy! if user.reload.persisted? }
  end

  test "simultaneous retries create exactly one batch" do
    sender = create_user("sender")
    create_user("recipient")
    key = SecureRandom.uuid
    ids = concurrently(2) do
      VoiceDropDispatcher.new(User.find(sender.id), language: @language).call(
        audio: audio_upload, duration_ms: 1000, request_key: key).id
    end
    assert_equal 1, ids.uniq.size
    assert_equal 1, VoiceDrop.where(sender: sender).count
    drop = VoiceDrop.find(ids.first)
    assert_equal drop.recipient_count, drop.voice_deliveries.count
    assert_equal drop.recipient_count, drop.rooms.count
  end

  test "different simultaneous recordings cannot create duplicate active pairs" do
    sender = create_user("sender")
    create_user("recipient")
    outcomes = concurrently(2) do
      begin
        VoiceDropDispatcher.new(User.find(sender.id), language: @language).call(
          audio: audio_upload, duration_ms: 1000, request_key: SecureRandom.uuid)
        :sent
      rescue VoiceDropDispatcher::NoRecipientAvailable
        :no_candidates
      end
    end
    assert_includes outcomes, :sent
    assert Room.where(user: sender, language: @language).group(:opponent_id).count.values.all? { |count| count == 1 }
  end

  test "concurrent senders cannot overload a recipient past the pending limit" do
    receiver = create_user("receiver")
    senders = 4.times.map { |i| create_user("sender-#{i}") }
    queue = Queue.new
    senders.each { |sender| queue << sender.id }
    concurrently(4) do
      sender = User.find(queue.pop)
      begin
        VoiceDropDispatcher.new(sender, language: @language).call(
          audio: audio_upload, duration_ms: 1000, request_key: SecureRandom.uuid)
      rescue VoiceDropDispatcher::NoRecipientAvailable
        nil
      end
    end
    pending = VoiceMatching::RecipientStats.new([receiver]).call.fetch(receiver.id)[:pending_conversations]
    assert_equal 3, pending
  end

  private

  def concurrently(count)
    ready = Queue.new
    start = Queue.new
    threads = count.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          yield
        end
      end
    end
    count.times { ready.pop }
    count.times { start << true }
    threads.map(&:value)
  end

  def create_user(role)
    user = User.create!(oauth_provider: :google, oauth_uid: "#{@tag}-#{role}", email_address: "#{@tag}-#{role}@example.com",
      mother_language: @other, learning_language: @language, last_active_at: Time.current)
    @users << user
    user
  end

  def audio_upload
    { io: StringIO.new("voice-message"), filename: "voice.webm", content_type: "audio/webm" }
  end
end
