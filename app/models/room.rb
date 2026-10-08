class Room < ApplicationRecord
  belongs_to :host, class_name: "User", optional: true
  belongs_to :language
  belongs_to :opponent, class_name: "User", optional: true
  has_many :voice_messages, dependent: :destroy
  has_one :last_voice_message, -> { order(created_at: :desc, id: :desc) }, class_name: "VoiceMessage"
  has_many :content_reports, dependent: :destroy

  enum :status, { active: "active", deleted: "deleted" }, default: :active
  validate :participants_must_be_different

  scope :involving, ->(participant) { where(host_id: participant.id).or(where(opponent_id: participant.id)) }
  scope :visible_to, ->(participant) {
    replied_room_ids = VoiceMessage.where.not(sender_id: participant.id).select(:room_id)
    involving(participant)
      .where("deleted_by_id IS NULL OR deleted_by_id != ?", participant.id)
      .where("dismissed_by_id IS NULL OR dismissed_by_id != ?", participant.id)
      .where("opponent_id = :id OR id IN (:replied) OR host_id IS NULL OR opponent_id IS NULL OR status = 'deleted'", id: participant.id, replied: replied_room_ids)
  }

  def self.between(first_user, second_user)
    where(host_id: first_user.id, opponent_id: second_user.id).or(where(host_id: second_user.id, opponent_id: first_user.id))
  end

  def opponent_for(participant)
    return opponent if host_id == participant.id
    return host if opponent_id == participant.id
    raise ActiveRecord::RecordNotFound, "User is not a participant in this room"
  end

  def deleted_by?(participant)
    deleted_by_id == participant.id
  end

  def unavailable?(participant)
    deleted? || opponent_for(participant).nil? ||
      UserBlock.exists_between?(participant, opponent_for(participant)) ||
      content_reports.where(status: ["pending", "reviewed", "actioned"]).exists?
  end

  def can_reply?(participant)
    other = opponent_for(participant)
    other.present? && last_voice_message&.sender_id == other.id
  end

  private

  def participants_must_be_different
    errors.add(:opponent, "must be a different user") if host_id.present? && host_id == opponent_id
  end
end
