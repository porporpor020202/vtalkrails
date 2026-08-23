class UserBlock < ApplicationRecord
  belongs_to :blocker, class_name: "User", inverse_of: :initiated_blocks
  belongs_to :blocked, class_name: "User", inverse_of: :received_blocks

  validates :blocked_id, uniqueness: { scope: :blocker_id }
  validate :users_must_be_different

  def self.exists_between?(first_user, second_user)
    where(blocker: first_user, blocked: second_user)
      .or(where(blocker: second_user, blocked: first_user))
      .exists?
  end

  private

  def users_must_be_different
    errors.add(:blocked, "must be a different user") if blocker_id.present? && blocker_id == blocked_id
  end
end
