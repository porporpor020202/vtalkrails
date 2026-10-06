class Room < ApplicationRecord
  belongs_to :host, class_name: "User"
  belongs_to :language
  belongs_to :opponent, class_name: "User"

  has_many :voice_messages, dependent: :destroy
  has_one :last_voice_message, -> { order(created_at: :desc, id: :desc) }, class_name: "VoiceMessage"
  has_many :content_reports, dependent: :destroy

  validate :participants_must_be_different

  scope :involving, ->(participant) {
    where(host_id: participant.id).or(where(opponent_id: participant.id))
  }

  scope :visible_to, ->(participant) {
    replied_room_ids = VoiceMessage.where.not(sender_id: participant.id).select(:room_id)
    where(opponent: participant).or(where(host: participant, id: replied_room_ids))
  }

  def self.between(first_user, second_user)
    where(host_id: first_user.id, opponent_id: second_user.id)
      .or(where(host_id: second_user.id, opponent_id: first_user.id))
  end

  def opponent_for(participant)
    return opponent if host_id == participant.id
    return host if opponent_id == participant.id

    raise ActiveRecord::RecordNotFound, "User is not a participant in this room"
  end

  def can_reply?(participant)
    last_voice_message&.sender_id == opponent_for(participant).id
  end

  private

  def participants_must_be_different
    errors.add(:opponent, "must be a different user") if host_id.present? && host_id == opponent_id
  end
end
