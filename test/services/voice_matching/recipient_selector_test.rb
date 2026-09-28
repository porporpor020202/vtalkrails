require "test_helper"

class RecipientSelectorTest < ActiveSupport::TestCase
  test "weight rewards activity replies and availability while penalizing load" do
    selector = VoiceMatching::RecipientSelector.new(sender: users(:english_speaker), language: languages(:english))
    baseline = { hours_since_active: 1, matured_deliveries: 20, replied_within_24h: 10,
      availability: 0.5, pending_conversations: 0, deliveries_last_24h: 0 }
    base = selector.weight(baseline)
    assert_operator selector.weight(baseline.merge(hours_since_active: 48)), :<, base
    assert_operator selector.weight(baseline.merge(replied_within_24h: 18)), :>, base
    assert_operator selector.weight(baseline.merge(availability: 0.9)), :>, base
    assert_operator selector.weight(baseline.merge(pending_conversations: 2)), :<, base
    assert_operator selector.weight(baseline.merge(deliveries_last_24h: 20)), :<, base
    assert selector.weight(baseline.merge(hours_since_active: nil, matured_deliveries: 0, replied_within_24h: 0)).finite?
  end

  test "seeded selection is reproducible but different seeds explore different recipients" do
    6.times do |i|
      User.create!(email_address: "sample#{i}@example.com", oauth_provider: :google, oauth_uid: "sample#{i}",
        mother_language: languages(:korean), learning_language: languages(:english))
    end
    sample = ->(seed) { VoiceMatching::RecipientSelector.new(sender: users(:english_speaker), language: languages(:english), random: Random.new(seed)).call(limit: 3).map(&:id) }
    assert_equal sample.call(12), sample.call(12)
    assert_equal 3, sample.call(12).uniq.size
    assert_operator (1..6).map { |seed| sample.call(seed) }.uniq.size, :>, 1
  end

  test "activity is throttled and browser timezone is validated" do
    user = users(:english_speaker)
    user.update_columns(last_active_at: nil)
    now = Time.current
    VoiceMatching::ActivityTracker.call(user, time_zone: "Asia/Seoul", now: now)
    VoiceMatching::ActivityTracker.call(user, time_zone: "Not/AZone", now: now + 1.minute)
    assert_equal "Asia/Seoul", user.reload.time_zone
    assert_equal 1, UserActivityHour.where(user: user).sum(:samples)
    VoiceMatching::ActivityTracker.call(user, time_zone: "Not/AZone", now: now + 6.minutes)
    assert_equal "Asia/Seoul", user.reload.time_zone
    assert_equal 2, UserActivityHour.where(user: user).sum(:samples)
  end

  test "reply statistics exclude deliveries still inside the response window and count both room sides" do
    user = users(:korean_learner)
    sender = users(:english_speaker)
    now = Time.current
    drop = VoiceDrop.create!(sender: sender, language: languages(:english), request_key: SecureRandom.uuid)
    drop.voice_deliveries.create!(recipient: user, created_at: now - 2.days, first_replied_at: now - 2.days + 1.hour)
    newer = VoiceDrop.create!(sender: sender, language: languages(:english), request_key: SecureRandom.uuid)
    newer.voice_deliveries.create!(recipient: user, created_at: now - 1.hour)
    Room.create!(user: user, opponent: sender, language: languages(:english), last_sender: sender)
    Room.create!(user: sender, opponent: user, language: languages(:korean), last_sender: sender)
    stats = VoiceMatching::RecipientStats.new([user], now: now).call.fetch(user.id)
    assert_equal 1, stats[:matured_deliveries]
    assert_equal 1, stats[:replied_within_24h]
    assert_equal 1, stats[:deliveries_last_24h]
    assert_equal 2, stats[:pending_conversations]
  end
end
