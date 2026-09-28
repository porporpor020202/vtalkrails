class Comment < ApplicationRecord
  belongs_to :post, counter_cache: true
  belongs_to :user

  normalizes :body, with: ->(body) { body.strip }
  validates :body, presence: true, length: { maximum: 500 }
end
