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
  has_many :initiated_blocks,
    class_name: "UserBlock",
    foreign_key: :blocker_id,
    inverse_of: :blocker,
    dependent: :destroy
  has_many :received_blocks,
    class_name: "UserBlock",
    foreign_key: :blocked_id,
    inverse_of: :blocked,
    dependent: :destroy
  has_many :submitted_content_reports,
    class_name: "ContentReport",
    foreign_key: :reporter_id,
    inverse_of: :reporter,
    dependent: :destroy
  has_many :received_content_reports,
    class_name: "ContentReport",
    foreign_key: :reported_user_id,
    inverse_of: :reported_user,
    dependent: :destroy

  enum :oauth_provider, { apple: "apple", google: "google" }

  normalizes :email_address, with: ->(e) { e.strip.downcase if e }

  # TODO: OAUTH가입시에 레이스컨디션 발생 안하도록 코드 작성해야함. uid + provider 조합 unique 설정. 인덱스도 설정하라는데 뭔지모르겠음.
  validates :oauth_uid, presence: true
  validates :oauth_provider, presence: true

  validates :display_name, presence: true, uniqueness: true

  before_validation :assign_display_name

  private

  def assign_display_name
    self.display_name = UserDisplayNameGenerator.display_name
  end
end
