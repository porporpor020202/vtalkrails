class Language < ApplicationRecord
  has_many :posts, dependent: :restrict_with_error
  has_many :rooms, dependent: :restrict_with_error

  validates :name, :code, presence: true
  validates :code, uniqueness: true
end
