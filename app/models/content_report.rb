class ContentReport < ApplicationRecord
  REASONS = {
    harassment: "Harassment or bullying",
    hate_speech: "Hate speech",
    sexual_content: "Sexual content",
    threats: "Threats or violence",
    spam: "Spam or scam",
    other: "Other"
  }.freeze

  belongs_to :room
  belongs_to :reporter, class_name: "User", inverse_of: :submitted_content_reports
  belongs_to :reported_user, class_name: "User", inverse_of: :received_content_reports

  enum :reason, REASONS.keys.index_with(&:to_s), validate: true
  enum :status, { pending: "pending", reviewed: "reviewed", actioned: "actioned", dismissed: "dismissed" }, default: :pending

  validates :details, length: { maximum: 1_000 }
  validate :reporter_must_belong_to_room
  validate :reported_user_must_be_the_other_participant

  private

  def reporter_must_belong_to_room
    return if room.blank? || reporter.blank?
    return if room.user_id == reporter_id || room.opponent_id == reporter_id

    errors.add(:reporter, "must belong to the conversation")
  end

  def reported_user_must_be_the_other_participant
    return if room.blank? || reporter.blank? || reported_user.blank?
    return if room.opponent_for(reporter).id == reported_user_id

    errors.add(:reported_user, "must be the other conversation participant")
  end
end
