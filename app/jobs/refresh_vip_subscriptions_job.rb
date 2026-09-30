class RefreshVipSubscriptionsJob < ApplicationJob
  def perform
    BillingEvent.where(processed_at: nil).where("created_at < ?", 5.minutes.ago).find_each do |event|
      BillingEventJob.perform_later(event.id)
    end
    VipSubscription.where("verified_at < ? AND (expires_at > ? OR auto_renew = ?)", 1.hour.ago, 2.days.ago, true).find_each do |subscription|
      begin
        Billing::Sync.call(subscription.provider, subscription.external_id)
      rescue Billing::Error => error
        Rails.logger.warn("VIP refresh failed for subscription #{subscription.id}: #{error.class.name}")
      end
    end
  end
end
