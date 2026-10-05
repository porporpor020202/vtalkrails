class VoiceMessage < ApplicationRecord
  belongs_to :room
  belongs_to :sender, class_name: "User"
  belongs_to :voice_drop, optional: true
  has_one_attached :audio

  validates :duration_ms, numericality: { only_integer: true, greater_than: 0 }
  validates :audio, presence: true
end
