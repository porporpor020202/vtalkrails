class Post < ApplicationRecord
  belongs_to :language
  belongs_to :user
  has_many :comments, dependent: :destroy

  normalizes :body, with: ->(body) { body.strip }
  validates :body, presence: true, length: { maximum: 2000 }
end
