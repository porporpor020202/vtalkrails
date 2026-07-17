class Room < ApplicationRecord
  belongs_to :user
  belongs_to :opponent, class_name: "User"

  enum :status, { your_turn: 0, waiting: 1, deleted: 2 }, default: :waiting

  validates :status, presence: true
end
