class AiAssistance < ApplicationRecord
  KINDS = %w[interpretation suggestions translation pronunciation].freeze
  belongs_to :user
  belongs_to :room
  belongs_to :source_message, class_name: "VoiceMessage"
  has_one_attached :audio

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: %w[pending processing completed failed] }
  validates :input_text, length: { maximum: 1000 }

  def accessible?
    !room.deleted? && !room.hidden_for?(user) &&
      [ room.user_id, room.opponent_id ].include?(user_id) &&
      source_message.room_id == room_id
  end

  def current_turn?
    return true if kind == "interpretation"
    room.can_reply?(user) &&
      room.voice_messages.order(:created_at, :id).last&.id == source_message_id
  end
end
