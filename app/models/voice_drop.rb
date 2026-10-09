class VoiceDrop < ApplicationRecord
  belongs_to :sender, class_name: "User"
  has_many :voice_messages, dependent: :nullify
  has_many :rooms, through: :voice_messages

  validates :request_key, presence: true, uniqueness: { scope: :sender_id }
  validates :recipient_count, numericality: { only_integer: true, greater_than: 0 }
end
