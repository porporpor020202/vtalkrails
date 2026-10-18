class DailyPractice < ApplicationRecord
  belongs_to :user
  belongs_to :daily_question
  has_one_attached :audio, dependent: :purge_later

  validates :practiced_on, presence: true, uniqueness: { scope: :user_id }
  validates :completed_at, presence: true
  validates :duration_ms, numericality: { only_integer: true, greater_than_or_equal_to: 1000, less_than_or_equal_to: 60000 }
  validates :audio, presence: true
  validate :valid_recording

  private

  def valid_recording
    return unless audio.attached?
    errors.add(:audio, "must be an audio recording") unless %w[audio/webm video/webm audio/mp4 audio/x-m4a audio/mpeg audio/ogg audio/wav audio/x-wav].include?(audio.blob.content_type)
    errors.add(:audio, "must be smaller than 10 MB") if audio.blob.byte_size > 10.megabytes
    errors.add(:audio, "cannot be empty") if audio.blob.byte_size.zero?
  end
end
