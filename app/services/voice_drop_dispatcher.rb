class VoiceDropDispatcher
  ACTIVE_WINDOW = 7.days
  RECENT_WINDOW = 24.hours
  MAX_PENDING_ROOMS = 3
  CANDIDATE_LIMIT = 100

  class NoRecipientAvailable < StandardError; end

  def initialize(sender)
    @sender = sender
  end

  def call(audio:, duration_ms:)
    ranked_candidates.each do |recipient|
      room = create_room_with_message(recipient, audio:, duration_ms:)
      return room if room
    end

    # Previous production message while the active-user filter was enabled:
    # raise NoRecipientAvailable, "No active listener is available right now"
    raise NoRecipientAvailable, "No listener account is available right now"
  end

  private

  attr_reader :sender

  def ranked_candidates
    User.registered
      # Store review: keep registered Apple and Google review accounts eligible
      # even when either account has not been active during the last 7 days.
      # Re-enable this scope after review if recent activity should be required:
      # .active_since(ACTIVE_WINDOW.ago)
      .where.not(id: sender.id)
      .order(last_active_at: :desc)
      .limit(CANDIDATE_LIMIT)
      # A deleted conversation should not block a new voice drop between the
      # same users. Only an active room means this pair is already engaged.
      .reject { |candidate| active_room_between?(candidate) }
      .map { |candidate| [ candidate, pending_room_count(candidate), candidate.last_active_at ] }
      .select { |_, pending_count, _| pending_count < MAX_PENDING_ROOMS }
      .sort_by { |_, pending_count, last_active_at| [ last_active_at.nil? || last_active_at < RECENT_WINDOW.ago ? 1 : 0, pending_count, rand ] }
      .map(&:first)
  end

  def pending_room_count(candidate)
    Room.involving(candidate)
      .where.not(last_sender_id: nil)
      .where.not(last_sender_id: candidate.id)
      .count
  end

  def create_room_with_message(recipient, audio:, duration_ms:)
    room = nil

    ApplicationRecord.transaction do
      User.where(id: [ sender.id, recipient.id ]).order(:id).lock.load
      next if active_room_between?(recipient)

      room = Room.create!(
        user: sender,
        opponent: recipient,
        status: :waiting,
        last_sender: sender,
        last_message_at: Time.current
      )
      message = room.voice_messages.build(sender:, duration_ms:)
      message.audio.attach(audio)
      message.save!
    end

    room
  end

  def active_room_between?(recipient)
    Room.between(sender, recipient).where.not(status: :deleted).exists?
  end
end
