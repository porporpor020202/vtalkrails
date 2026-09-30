class VipSubscription < ApplicationRecord
  belongs_to :user
  validates :provider, inclusion: { in: %w[paddle apple google] }
  scope :entitled, -> { where(status: %w[active grace canceled]).where("expires_at > ?", Time.current) }

  def active?
    %w[active grace canceled].include?(status) && expires_at&.future?
  end
end
