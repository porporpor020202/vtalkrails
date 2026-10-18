class DailyQuestion < ApplicationRecord
  has_many :daily_practices, dependent: :restrict_with_exception
  validates :asked_on, presence: true, uniqueness: true
  validates :question, presence: true, length: { maximum: 240 }
  validates :source, inclusion: { in: %w[gemini sample] }

  def self.for_date(date)
    find_by(asked_on: date) || begin
      text = GeminiQuestion.new.call(date: date)
      create!(asked_on: date, question: text, source: "gemini")
    rescue GeminiQuestion::Unavailable => error
      Rails.logger.warn("Daily question unavailable: #{error.message}")
      # An explicitly labeled sample keeps practice available during setup or outages.
      samples = [ "What made you smile today?", "What is your favorite way to relax?", "What would you like to do tomorrow?", "What is a food you really enjoy?", "What is one thing you are grateful for?", "Where would you like to travel?", "What do you like about your morning?" ]
      create!(asked_on: date, question: samples[date.jd % samples.length], source: "sample")
    end
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    find_by!(asked_on: date)
  end
end
