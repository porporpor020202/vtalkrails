class Room < ApplicationRecord
  belongs_to :user
  belongs_to :opponent, class_name: "User"
  belongs_to :last_sender, class_name: "User", optional: true
  belongs_to :deleted_by, class_name: "User", optional: true
  belongs_to :dismissed_by, class_name: "User", optional: true

  has_many :voice_messages, dependent: :destroy

  enum :status, { your_turn: 0, waiting: 1, deleted: 2 }, default: :waiting

  validates :status, presence: true
  validate :participants_must_be_different

  scope :involving, ->(participant) {
    where(user_id: participant.id).or(where(opponent_id: participant.id))
  }

  scope :visible_to, ->(participant) {
    active = involving(participant).where.not(status: :deleted)
    ended_by_other = involving(participant)
      .where(status: :deleted)
      .where.not(deleted_by_id: participant.id)
      .where("rooms.dismissed_by_id IS NULL OR rooms.dismissed_by_id != ?", participant.id)

    active.or(ended_by_other)
  }

  def self.between(first_user, second_user)
    where(user_id: first_user.id, opponent_id: second_user.id)
      .or(where(user_id: second_user.id, opponent_id: first_user.id))
  end

  def opponent_for(participant)
    return opponent if user_id == participant.id
    return user if opponent_id == participant.id

    raise ActiveRecord::RecordNotFound, "User is not a participant in this room"
  end

  def can_reply?(participant)
    !deleted? && involving_user?(participant) && (last_sender_id.nil? || last_sender_id != participant.id)
  end

  def deleted_by?(participant)
    deleted? && deleted_by_id == participant.id
  end

  def hidden_for?(participant)
    deleted? && (deleted_by_id == participant.id || dismissed_by_id == participant.id)
  end

  def waiting_for_reply_from?(participant)
    last_sender_id == participant.id
  end

  private

  def involving_user?(participant)
    user_id == participant.id || opponent_id == participant.id
  end

  def participants_must_be_different
    errors.add(:opponent, "must be a different user") if user_id.present? && user_id == opponent_id
  end
end
