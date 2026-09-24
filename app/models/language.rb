class Language < ApplicationRecord
  has_many :rooms, dependent: :restrict_with_error

  validates :name, :code, presence: true
  validates :code, uniqueness: true
end
