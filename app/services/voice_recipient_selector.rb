class VoiceRecipientSelector
  def self.recipient_limit
    Rails.configuration.x.voice_recipient_selection.recipient_limit
  end

  def self.activity_window
    Rails.configuration.x.voice_recipient_selection.activity_window
  end

  def self.recipients(sender:, language:)
    now = Time.current

    User.where(native_language: language)
      .or(User.where(learning_language: language))
      .where.not(id: sender.id)
      .where(last_active_at: (now - activity_window)..now)
      .order(last_active_at: :desc, id: :asc)
      .limit(recipient_limit)
  end
end
