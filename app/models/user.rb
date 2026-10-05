class User < ApplicationRecord
  # 1. Associations
  belongs_to :native_language, class_name: "Language", optional: true
  belongs_to :learning_language, class_name: "Language", optional: true
  has_many :voice_drops, foreign_key: :sender_id, dependent: :destroy
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
  validates :display_name, presence: true, on: :onboarding

  validates :native_language, :learning_language,
            presence: true,
            on: [ :onboarding, :language_setup ]

  validate :languages_enabled, on: [ :onboarding, :language_setup ]
  validate :learning_language_differs_from_native_language

  # 5. Callbacks

  # 6. Normalizations
  normalizes :email_address, with: ->(e) { e.strip.downcase if e }
  normalizes :display_name, with: ->(name) { name.strip.presence }

  # 7. Public Methods / Custom Logic
  def onboarding_complete?
    display_name.present? && native_language.present? &&
      learning_language.present? && native_language_id != learning_language_id
  end

  def profile_image_path_for
    noun = display_name.to_s.split(" ", 2).last.to_s.sub(/ \d+\z/, "")
    UserDisplayNameGenerator::ALL_IMAGE_PATHS_BY_NOUN.fetch(
      noun, "emoji/animals_and_nature/raccoon_3d.png"
    )
  end

  # 8. Private Methods
  private

  # TODO: 공식문서 이해하자.
  def languages_enabled
    [ :native_language, :learning_language ].each do |attribute|
      language = public_send(attribute)
      errors.add(attribute, "is not enabled") if language && !language.enable?
    end
  end

  # TODO: 공식문서 이해하자.
  def learning_language_differs_from_native_language
    if learning_language_id.present? && learning_language_id == native_language_id
      errors.add(:learning_language, "must be different from native language")
    end
  end
end
