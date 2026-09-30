class BillingEventJob < ApplicationJob
  retry_on Billing::Error, wait: :polynomially_longer, attempts: 8

  def perform(id)
    event = BillingEvent.find_by(id: id)
    return unless event && !event.processed_at
    Billing::Sync.call(event.provider, event.reference)
    event.update!(processed_at: Time.current)
  rescue Billing::InvalidPurchase
    # Invalid products, removed owners, and mismatched accounts never grant access.
    event&.update!(processed_at: Time.current)
  end
end
