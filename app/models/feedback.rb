class Feedback < ApplicationRecord
  belongs_to :user
  has_many :feedback_replies, dependent: :destroy

  validates :title, :body, presence: true
end
