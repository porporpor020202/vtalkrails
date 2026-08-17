class VoiceMessage < ApplicationRecord
  MAX_DURATION_MS = 30_000
  MAX_AUDIO_BYTES = 8.megabytes
  ALLOWED_AUDIO_TYPES = %w[
    audio/mp4
    audio/webm
    audio/ogg
    audio/mpeg
    audio/wav
    audio/x-m4a
    video/mp4
  ].freeze

  belongs_to :room, touch: true
  belongs_to :sender, class_name: "User", inverse_of: :voice_messages

  has_one_attached :audio

  validates :duration_ms,
    numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_DURATION_MS }
  validate :sender_must_belong_to_room
  validate :acceptable_audio

  def duration_seconds
    (duration_ms / 1000.0).ceil
  end

  private

  def sender_must_belong_to_room
    return if room.blank? || sender.blank?
    return if room.user_id == sender_id || room.opponent_id == sender_id

    errors.add(:sender, "must belong to the room")
  end

  def acceptable_audio
    unless audio.attached?
      errors.add(:audio, "is required")
      return
    end

    content_type = audio.blob.content_type.to_s.split(";").first
    errors.add(:audio, "must be a supported audio file") unless ALLOWED_AUDIO_TYPES.include?(content_type)
    errors.add(:audio, "must be smaller than 8 MB") if audio.blob.byte_size > MAX_AUDIO_BYTES
  end
end
