class Country < ApplicationRecord
  validates :code, presence: true, uniqueness: true, format: { with: /\A[A-Z]{2}\z/ }
  validates :name, presence: true
end
