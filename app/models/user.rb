class User < ApplicationRecord
  ADMIN_EMAIL = "porporpor020202@gmail.com".freeze
  has_many :sessions, dependent: :destroy
  has_many :daily_practices, dependent: :destroy
  has_many :bonus_practices, through: :daily_practices
  has_many :marketing_visits, dependent: :destroy
  has_many :marketing_events, dependent: :delete_all
  after_create_commit :record_marketing_signup

  validates :oauth_provider, inclusion: { in: %w[apple google] }
  validates :oauth_uid, presence: true, uniqueness: { scope: :oauth_provider }
  validates :native_language, inclusion: { in: NativeLanguage::OPTIONS.keys }, allow_nil: true
  validates :email_address, presence: true
  normalizes :email_address, with: ->(email) { email&.strip&.downcase }

  def admin?
    email_address == ADMIN_EMAIL
  end

  def marketing_internal?
    admin? || email_address.end_with?("@cloudtestlabaccounts.com")
  end

  def streak(today: Date.current)
    dates = daily_practices.where.not(completed_at: nil).where("practiced_on <= ?", today).order(practiced_on: :desc).pluck(:practiced_on)
    expected = dates.first == today ? today : today.yesterday
    dates.take_while { |date| matches = date == expected; expected -= 1; matches }.length
  end

  private

  def record_marketing_signup
    MarketingEvent.capture(name: "signup", user: self, occurred_at: created_at, deduplication_key: "signup:#{id}")
  end
end
