class User < ApplicationRecord
  # 1. Associations
  has_many :voice_drops, foreign_key: :sender_id, dependent: :destroy
  has_many :voice_deliveries, foreign_key: :recipient_id, dependent: :destroy
  has_many :sessions, dependent: :destroy
  has_many :rooms, dependent: :destroy
  has_many :opponent_rooms, class_name: "Room", foreign_key: :opponent_id, inverse_of: :opponent, dependent: :destroy
  has_many :voice_messages, foreign_key: :sender_id, inverse_of: :sender, dependent: :destroy
  has_many :notification_tokens, dependent: :destroy
  has_many :initiated_blocks, class_name: "UserBlock", foreign_key: :blocker_id, inverse_of: :blocker, dependent: :destroy
  has_many :received_blocks, class_name: "UserBlock", foreign_key: :blocked_id, inverse_of: :blocked, dependent: :destroy
  has_many :submitted_content_reports, class_name: "ContentReport", foreign_key: :reporter_id, inverse_of: :reporter, dependent: :destroy
  has_many :received_content_reports, class_name: "ContentReport", foreign_key: :reported_user_id, inverse_of: :reported_user, dependent: :destroy

  # 2. Enums
  enum :oauth_provider, { apple: "apple", google: "google" }

  # 3. Scopes

  # 4. Validations
  validates :oauth_provider, presence: true
  validates :oauth_uid, presence: true, uniqueness: { scope: :oauth_provider }
  validates :email_address, presence: true
  validates :display_name, uniqueness: true, allow_nil: true
  validates :display_name, :country_code, presence: true, on: :onboarding
  validate :country_code_must_exist, on: :onboarding

  validates :native_language, presence: true, on: :language_setup

  # 5. Callbacks

  # 6. Normalizations
  normalizes :email_address, with: ->(e) { e.strip.downcase if e }
  normalizes :display_name, with: ->(name) { name.strip.presence }

  # 7. Public Methods / Custom Logic
  def onboarding_complete?
    display_name.present? && country_code.present?
  end

  def profile_image_path_for
    noun = display_name.to_s.split(" ", 2).last.to_s.sub(/ \d+\z/, "")
    UserDisplayNameGenerator::ALL_IMAGE_PATHS_BY_NOUN.fetch(
      noun, "emoji/animals_and_nature/raccoon_3d.png"
    )
  end

  private

  # 8. Private Methods
  def country_code_must_exist
    return if country_code.blank? || Country.exists?(code: country_code)

    errors.add(:country_code, "is not a supported country or region")
  end
end
