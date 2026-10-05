class VoiceDispatcher
  class NoRecipientAvailable < StandardError; end

  def initialize(sender)
    @sender = sender
  end

  def call(language:, audio:, duration_ms:, request_key:)
    blob = nil

    @sender.with_lock do
      existing = @sender.voice_drops.find_by(request_key: request_key)
      next existing if existing

      recipients = VoiceRecipientSelector.recipients(sender: @sender, language: language).to_a
      if recipients.empty?
        raise NoRecipientAvailable, "No recipients are available right now. Please try again later."
      end

      blob = ActiveStorage::Blob.create_and_upload!(
        io: audio.tempfile,
        filename: audio.original_filename,
        content_type: audio.content_type
      )

      drop = @sender.voice_drops.create!(
        language: language,
        request_key: request_key,
        recipient_count: recipients.size
      )

      recipients.each do |recipient|
        room = Room.create!(host: @sender, opponent: recipient, language: language)
        message = room.voice_messages.build(sender: @sender, voice_drop: drop, duration_ms: duration_ms)
        message.audio.attach(blob)
        message.save!
      end

      drop
    end
  rescue StandardError
    # DB가 롤백되어도 스토리지에 업로드된 파일은 별도로 정리해야 한다.
    if blob && !ActiveStorage::Attachment.exists?(blob_id: blob.id)
      blob.service.delete(blob.key)
    end
    raise
  end
end
