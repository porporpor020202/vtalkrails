class VoiceDropDispatcher
  class NoRecipientAvailable < StandardError; end
  class RequestConflict < StandardError; end

  def initialize(sender)
    @sender = sender
    @config = Rails.application.config_for(:voice_matching)
  end

  def call(audio:, duration_ms:, request_key:)
    existing = VoiceDrop.find_by(sender: @sender, request_key: request_key)
    return existing if existing

    candidate_drop = VoiceDrop.new(sender: @sender, request_key: request_key)
    candidate_drop.validate!
    selector = VoiceMatching::RecipientSelector.new(sender: @sender)
    candidates = selector.call(limit: @config.fetch(:recipient_limit) * @config.fetch(:reserve_multiplier))
    raise NoRecipientAvailable, "No available listeners right now." if candidates.empty?

    blob = upload_validated_audio(audio, duration_ms, candidates.first)
    ApplicationRecord.transaction do
      # Global ID ordering prevents deadlocks between simultaneous senders.
      users = User.where(id: [@sender.id, *candidates.map(&:id)]).order(:id).lock.to_a
      @sender.reload
      unless @sender.language_setup_complete?
        raise RequestConflict, "Choose your native language before recording."
      end
      existing = VoiceDrop.find_by(sender: @sender, request_key: request_key)
      next existing if existing

      allowed = VoiceMatching::CandidateQuery.new(sender: @sender).call
        .where(id: candidates.map(&:id)).pluck(:id)
      stats = VoiceMatching::RecipientStats.new(users, config: @config).call
      recipients = candidates.select do |user|
        allowed.include?(user.id) && stats.fetch(user.id)[:pending_conversations] < @config.fetch(:max_pending_conversations)
      end.take(@config.fetch(:recipient_limit))
      raise NoRecipientAvailable, "No available listeners right now." if recipients.empty?

      drop = VoiceDrop.create!(sender: @sender, request_key: request_key, recipient_count: recipients.size)
      recipients.each do |recipient|
        room = Room.create!(user: @sender, opponent: recipient,
          status: :waiting, last_sender: @sender, last_message_at: Time.current)
        drop.voice_deliveries.create!(recipient: recipient, room: room)
        message = room.voice_messages.build(sender: @sender, duration_ms: duration_ms)
        message.audio.attach(blob)
        message.save!
      end
      drop
    end
  ensure
    # A failed transaction or a concurrent retry must not leave an uploaded orphan.
    blob.purge if blob&.persisted? && !blob.attachments.exists?
  end

  private

  def upload_validated_audio(audio, duration_ms, recipient)
    probe = VoiceMessage.new(sender: @sender, duration_ms: duration_ms,
      room: Room.new(user: @sender, opponent: recipient))
    probe.audio.attach(audio)
    probe.validate!
    blob = probe.audio.blob
    blob.save!
    io = audio.respond_to?(:tempfile) ? audio.tempfile : audio.fetch(:io)
    io.rewind
    blob.upload_without_unfurling(io)
    blob
  rescue
    blob&.purge if blob&.persisted?
    raise
  end
end
