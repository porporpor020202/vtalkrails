module Billing
  class Sync
    ADAPTERS = { "paddle" => Paddle, "apple" => Apple, "google" => Google }.freeze

    def self.call(provider, reference, expected_user: nil)
      raise InvalidPurchase, "Invalid reference" if reference.blank? || reference.bytesize > 4096
      adapter = ADAPTERS.fetch(provider) { raise InvalidPurchase, "Invalid provider" }
      observed_at = Time.current
      data = adapter.snapshot(reference)
      acknowledge = data.delete(:acknowledge)
      account_token = data.delete(:account_token).to_s
      raise InvalidPurchase, "Missing purchase owner" unless account_token.match?(/\A[0-9a-f-]{36}\z/i)
      owner = User.find_by(billing_account_token: account_token)
      raise InvalidPurchase, "Purchase belongs to a different account." unless owner && (!expected_user || owner.id == expected_user.id)
      owner.with_lock do
        key = Digest::SHA256.hexdigest(data.fetch(:external_id))
        subscription = VipSubscription.find_or_initialize_by(provider: provider, external_key: key)
        raise InvalidPurchase, "Purchase already belongs to another account." if subscription.persisted? && subscription.user_id != owner.id
        return subscription if subscription.persisted? && subscription.verified_at > observed_at
        subscription.assign_attributes(data.merge(user: owner, verified_at: observed_at))
        subscription.save!
        adapter.acknowledge(reference, subscription.product_id) if provider == "google" && acknowledge && subscription.active?
        owner.update!(paddle_checkout_id: nil) if provider == "paddle"
        subscription
      end
    rescue KeyError, ArgumentError
      raise InvalidPurchase, "Invalid subscription response"
    end
  end
end
