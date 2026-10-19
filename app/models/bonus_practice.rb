class BonusPractice < ApplicationRecord
  belongs_to :daily_practice
  has_one_attached :audio, dependent: :purge_later

  validates :daily_practice_id, uniqueness: true
  validates :question, presence: true, length: { maximum: 240 }
  validates :source, inclusion: { in: %w[gemini sample] }
  validates :shared_at, presence: true
  validates :duration_ms, numericality: { only_integer: true, greater_than_or_equal_to: 1000, less_than_or_equal_to: 60000 }, if: :completed?
  validates :audio, presence: true, if: :completed?
  validate :valid_recording

  delegate :practiced_on, :user_id, to: :daily_practice
  alias_method :asked_on, :practiced_on

  def completed?
    completed_at.present?
  end

  def self.unlock_for!(practice)
    transaction do
      # One shared bonus question per date, even when people share simultaneously.
      connection_pool.with_connection { |db| db.execute("SELECT pg_advisory_xact_lock(7316248903)") }
      existing = find_by(daily_practice: practice)
      next existing if existing

      shared_question = joins(:daily_practice).where(daily_practices: { practiced_on: practice.practiced_on }).first
      question, source = shared_question ? [ shared_question.question, shared_question.source ] : generate_question(practice)
      create!(daily_practice: practice, question: question, source: source, shared_at: Time.current)
    end
  end

  def self.generate_question(practice)
    question = GeminiQuestion.new.call(date: practice.practiced_on)
    raise GeminiQuestion::Unavailable, "Repeated daily question" if question == practice.daily_question.question
    [ question, "gemini" ]
  rescue GeminiQuestion::Unavailable => error
    Rails.logger.warn("Bonus question unavailable: #{error.message}")
    samples = [ "What is one small goal for tomorrow?", "What do you like to do on weekends?", "What is a place you enjoy visiting?", "What is your favorite kind of weather?" ]
    samples.reject! { |text| text == practice.daily_question.question }
    [ samples[practice.practiced_on.jd % samples.length], "sample" ]
  end
  private_class_method :generate_question

  validates :english_sentence, length: { maximum: 2000 }, allow_nil: true

  private

  def valid_recording
    return unless audio.attached?
    errors.add(:audio, "must be an audio recording") unless %w[audio/webm video/webm audio/mp4 audio/x-m4a audio/mpeg audio/ogg audio/wav audio/x-wav].include?(audio.blob.content_type)
    errors.add(:audio, "must be smaller than 10 MB") if audio.blob.byte_size > 10.megabytes
    errors.add(:audio, "cannot be empty") if audio.blob.byte_size.zero?
  end
end
