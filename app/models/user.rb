class User < ApplicationRecord
  # 1. Associations
  has_many :posts, dependent: :destroy
  has_many :comments, dependent: :destroy
  belongs_to :mother_language, class_name: "Language", optional: true
  belongs_to :learning_language, class_name: "Language", optional: true
  has_many :voice_drops, foreign_key: :sender_id, dependent: :destroy
  has_many :voice_deliveries, foreign_key: :recipient_id, dependent: :destroy
  has_many :user_activity_hours, dependent: :destroy
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
  validates :mother_language, presence: true, if: -> { mother_language_id.present? }
  validates :learning_language, presence: true, if: -> { learning_language_id.present? }
  validates :oauth_provider, presence: true
  validates :oauth_uid, presence: true, uniqueness: { scope: :oauth_provider }
  validates :email_address, presence: true
  validates :display_name, presence: true, uniqueness: true

  validates :mother_language, :learning_language, presence: true, on: :language_setup
  validate :languages_must_differ

  # 5. Callbacks
  before_validation :assign_display_name, on: :create, if: -> { display_name.blank? }

  # 6. Normalizations
  normalizes :email_address, with: ->(e) { e.strip.downcase if e }

  # 7. Public Methods / Custom Logic
  def language_setup_complete?
    mother_language.present? && learning_language.present? &&
      mother_language_id != learning_language_id
  end

  private

  # 8. Private Methods
  def languages_must_differ
    return if mother_language_id.blank? || learning_language_id.blank?
    return unless mother_language_id == learning_language_id

    errors.add(:learning_language, "must be different from your mother language")
  end

  def assign_display_name
    self.display_name = UserDisplayNameGenerator.display_name
  end
end
