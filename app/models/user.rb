class User < ApplicationRecord
  has_many :sessions, dependent: :destroy
  has_many :daily_practices, dependent: :destroy

  validates :oauth_provider, inclusion: { in: %w[apple google] }
  validates :oauth_uid, presence: true, uniqueness: { scope: :oauth_provider }
  validates :native_language, inclusion: { in: NativeLanguage::OPTIONS.keys }, allow_nil: true
  validates :email_address, presence: true
  normalizes :email_address, with: ->(email) { email&.strip&.downcase }

  def admin?
    email_address == "porporpor020202@gmail.com"
  end

  def streak(today: Date.current)
    dates = daily_practices.where.not(completed_at: nil).where("practiced_on <= ?", today).order(practiced_on: :desc).pluck(:practiced_on)
    expected = dates.first == today ? today : today.yesterday
    dates.take_while { |date| matches = date == expected; expected -= 1; matches }.length
  end
end
