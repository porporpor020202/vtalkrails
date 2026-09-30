class VoiceDrop < ApplicationRecord
  belongs_to :sender, class_name: "User"
  has_many :voice_deliveries, dependent: :destroy
  has_many :rooms, through: :voice_deliveries

  validates :request_key, presence: true, length: { maximum: 100 }, uniqueness: { scope: :sender_id }
end
