class Language < ApplicationRecord
  scope :enabled, -> { where(enable: true) }

  validates :label, :code, presence: true, uniqueness: true
end
