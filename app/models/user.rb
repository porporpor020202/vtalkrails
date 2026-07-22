class User < ApplicationRecord
  has_secure_password validations: false

  has_many :sessions, dependent: :destroy
  has_many :rooms, dependent: :destroy
  has_many :notification_tokens, dependent: :destroy

  enum :oauth_provider, { apple: 0, google: 1 }

  normalizes :email_address, with: ->(e) { e.strip.downcase if e }

  validates :email_address, presence: true, uniqueness: true, unless: :guest?
  validates :password, presence: true, on: :create, unless: -> { guest? || oauth_provider.present? }
  validates_confirmation_of :password, allow_nil: true
  validates :oauth_uid, presence: true, if: :oauth_provider?
  validates :oauth_provider, presence: true, if: :oauth_uid?

  scope :guest, -> { where(guest: true) }
  scope :registered, -> { where(guest: false) }
  scope :oauth, -> { where.not(oauth_provider: nil) }

  before_validation :assign_random_name_and_icon, on: :create

  private

  def assign_random_name_and_icon
    return if name.present? && icon.present?

    animals = [
      { name: "Raccoon", icon: "🦝" },
      { name: "Lion", icon: "🦁" },
      { name: "Fox", icon: "🦊" },
      { name: "Panda", icon: "🐼" },
      { name: "Cat", icon: "🐱" },
      { name: "Koala", icon: "🐨" },
      { name: "Tiger", icon: "🐯" },
      { name: "Rabbit", icon: "🐰" }
    ]
    random_animal = animals.sample
    self.name ||= random_animal[:name]
    self.icon ||= random_animal[:icon]
  end
end
