class User < ApplicationRecord
  # 1. Associations
  belongs_to :native_language, class_name: "Language", optional: true
  has_many :vip_subscriptions, dependent: :destroy

  def vip?
    vip_subscriptions.entitled.exists?
  end
  has_many :ai_assistances, dependent: :destroy
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
  validates :native_language, presence: true, if: -> { native_language_id.present? }
  validates :oauth_provider, presence: true
  validates :oauth_uid, presence: true, uniqueness: { scope: :oauth_provider }
  validates :email_address, presence: true
  validates :display_name, presence: true, uniqueness: true

  validates :native_language, presence: true, on: :language_setup

  # 5. Callbacks
  before_validation :assign_display_name, on: :create, if: -> { display_name.blank? }

  # 6. Normalizations
  normalizes :email_address, with: ->(e) { e.strip.downcase if e }

  # 7. Public Methods / Custom Logic
  def profile_image_path_for
    noun = display_name.split(" ", 2).last.sub(/ \d+\z/, "")
    UserDisplayNameGenerator::ALL_IMAGE_PATHS_BY_NOUN.fetch(noun)
  end

  private

  # 8. Private Methods
  def assign_display_name
    self.display_name = UserDisplayNameGenerator.display_name
  end
end
