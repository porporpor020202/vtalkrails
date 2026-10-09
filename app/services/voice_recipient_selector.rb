class VoiceRecipientSelector
  def self.recipient_limit
    Rails.configuration.x.voice_recipient_selection.recipient_limit
  end

  def self.activity_window
    Rails.configuration.x.voice_recipient_selection.activity_window
  end

  def self.recipients(sender:)
    now = Time.current

    User.where.not(id: sender.id)
      .where.not(id: UserBlock.where(blocker: sender).select(:blocked_id))
      .where.not(id: UserBlock.where(blocked: sender).select(:blocker_id))
      .where.not(age_confirmed_at: nil)
      .where(suspended_at: nil, receive_new_rooms: true)
      .where(last_active_at: (now - activity_window)..now)
      .order(last_active_at: :desc, id: :asc)
      .limit(recipient_limit)
  end
end
