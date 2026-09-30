module VipTestHelper
  def grant_vip(user, provider: "apple")
    id = SecureRandom.uuid
    user.vip_subscriptions.create!(provider: provider, external_id: id,
      external_key: Digest::SHA256.hexdigest(id), product_id: "vip.monthly",
      status: "active", expires_at: 1.month.from_now, auto_renew: true, verified_at: Time.current)
  end
end

ActiveSupport::TestCase.include(VipTestHelper)
