class VoiceDelivery < ApplicationRecord
  belongs_to :voice_drop
  belongs_to :recipient, class_name: "User"
  belongs_to :room, optional: true
end
