class User < ApplicationRecord
  has_secure_password validations: false

  has_many :sessions, dependent: :destroy
  has_many :rooms, dependent: :destroy
  has_many :opponent_rooms,
    class_name: "Room",
    foreign_key: :opponent_id,
    inverse_of: :opponent,
    dependent: :destroy
  has_many :voice_messages,
    foreign_key: :sender_id,
    inverse_of: :sender,
    dependent: :destroy
  has_many :notification_tokens, dependent: :destroy

  enum :oauth_provider, { apple: "apple", google: "google" }

  normalizes :email_address, with: ->(e) { e.strip.downcase if e }

  # Email addresses are provider metadata, not the account identity. A person
  # may intentionally have separate Apple and Google accounts with the same
  # email address, so account uniqueness is enforced by the database's
  # provider + oauth_uid index instead.
  validates :email_address, presence: true, unless: :guest?
  validates :password, presence: true, on: :create, unless: -> { guest? || oauth_provider.present? }
  validates_confirmation_of :password, allow_nil: true
  validates :oauth_uid, presence: true, if: :oauth_provider?
  validates :oauth_provider, presence: true, if: :oauth_uid?
  validates :name, uniqueness: true, allow_nil: true

  scope :guest, -> { where(guest: true) }
  scope :registered, -> { where(guest: false) }
  scope :oauth, -> { where.not(oauth_provider: nil) }
  scope :active_since, ->(time) { where(last_active_at: time..) }

  after_create :assign_generated_name_and_icon, if: -> { name.blank? || icon.blank? }

  private

  def assign_generated_name_and_icon
    identity = UserDisplayNameGenerator.for_id(id)
    update_columns(
      name: name.presence || identity.name,
      icon: icon.presence || identity.icon
    )
  end
end
