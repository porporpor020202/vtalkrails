class MarketingEvent < ApplicationRecord
  NAMES = %w[app_open question_viewed question_translation_used answer_translation_used recording_started recording_completed practice_completed signup login guest_recording_claimed].freeze
  CLIENT_NAMES = %w[app_open recording_started recording_completed].freeze
  belongs_to :marketing_visit, optional: true
  belongs_to :user, optional: true
  validates :name, inclusion: { in: NAMES }
  validates :context, inclusion: { in: %w[daily bonus] }
  validates :occurred_at, :deduplication_key, presence: true

  def self.capture(name:, deduplication_key:, user: nil, visit: nil, context: "daily", occurred_at: Time.current, authenticated: user.present?)
    return if user&.admin? || visit&.internal?

    create_or_find_by!(deduplication_key: deduplication_key) do |event|
      event.assign_attributes(name: name, user: user, marketing_visit: visit, context: context, occurred_at: occurred_at, authenticated: authenticated)
    end
  rescue ActiveRecord::ActiveRecordError => error
    Rails.logger.warn("Marketing event unavailable: #{error.class}")
    nil
  end

  def self.prune!
    where("occurred_at < ?", 180.days.ago).delete_all
    MarketingVisit.where("last_seen_at < ?", 180.days.ago).find_each(&:destroy!)
  end
end
