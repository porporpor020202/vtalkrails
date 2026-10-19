require "test_helper"
require_relative "../test_helpers/daily_practice_test_helper"

class MarketingReportTest < ActiveSupport::TestCase
  include DailyPracticeTestHelper

  test "next day retention uses KST signup cohorts unique accounts and completed days only" do
    first = second = waiting = nil
    travel_to(Time.zone.local(2026, 10, 18, 23, 55)) { first = signup("first", "youtube") }
    travel_to(Time.zone.local(2026, 10, 19, 23, 55)) { second = signup("second", "threads") }
    travel_to(Time.zone.local(2026, 10, 20, 23, 55)) { waiting = signup("waiting", "youtube") }
    travel_to Time.zone.local(2026, 10, 20, 0, 5) do
      2.times do
        visit = create_visit(user: second)
        MarketingEvent.capture(name: "app_open", user: second, visit: visit, deduplication_key: SecureRandom.uuid)
      end
      complete_practice(second)
    end
    travel_to Time.zone.local(2026, 10, 20, 12) do
      visit = create_visit(user: first)
      MarketingEvent.capture(name: "app_open", user: first, visit: visit, deduplication_key: SecureRandom.uuid)
      complete_practice(first)
    end
    travel_to Time.zone.local(2026, 10, 21, 12) do
      visit = create_visit(user: waiting)
      MarketingEvent.capture(name: "app_open", user: waiting, visit: visit, deduplication_key: SecureRandom.uuid)
      complete_practice(waiting)
      report = MarketingReport.new(from: Date.new(2026, 10, 18), through: Date.new(2026, 10, 20))
      assert_equal({ signups: 2, returned: 1, practiced: 1, pending: 1 }, report.retention_totals)
      assert_equal [ Date.new(2026, 10, 20), Date.new(2026, 10, 19), Date.new(2026, 10, 18) ], report.retention.map { |row| row[:date] }
      assert_equal 1, report.retention.first[:returned], "In-progress days can show counts but must not enter the final rate."
      assert_equal 0, report.retention.last[:returned], "Coming back two days later is not D1 retention."
      filtered = MarketingReport.new(from: report.from, through: report.through, source: "threads")
      assert_equal({ signups: 1, returned: 1, practiced: 1, pending: 0 }, filtered.retention_totals)
    end
  end

  test "recording followed by existing-account login is not a new signup conversion" do
    visit = create_visit
    %w[recording_started recording_completed practice_completed].each do |name|
      2.times { MarketingEvent.capture(name: name, visit: visit, deduplication_key: "#{visit.id}:#{name}") }
    end
    MarketingEvent.capture(name: "login", visit: visit, user: users(:korean_native), deduplication_key: "existing-login")
    unrelated = signup("other-device", "direct")
    report = MarketingReport.new(from: Date.current, through: Date.current)
    assert_equal 1, report.summary[:guest_recorders]
    assert_equal 0, report.summary[:recorded_then_signup]
    assert_equal 1, report.summary[:recording_completed]
    assert_equal 1, report.summary[:practice_completed]
    assert_equal 1, report.summary[:new_accounts]
    assert unrelated.persisted?
  end

  test "old analytics are pruned without removing accounts or saved recordings" do
    old = recent = nil
    travel_to 181.days.ago do
      old = create_visit(user: users(:korean_native))
      MarketingEvent.capture(name: "app_open", visit: old, user: old.user, deduplication_key: "old")
    end
    recent = create_visit(user: users(:korean_native))
    complete_practice(users(:korean_native))
    assert_no_difference [ "User.count", "DailyPractice.count" ] do
      MarketingEvent.prune!
    end
    assert_not MarketingVisit.exists?(old.id)
    assert MarketingVisit.exists?(recent.id)
    assert_not MarketingEvent.where(deduplication_key: "old").exists?
  end

  test "an actual next-day practice proves return even if the visit beacon was lost" do
    user = nil
    travel_to(3.days.ago) { user = signup("lost-beacon", "youtube") }
    complete_practice(user, user.created_at.to_date.next_day)
    report = MarketingReport.new(from: user.created_at.to_date, through: user.created_at.to_date)
    assert_equal({ signups: 1, returned: 1, practiced: 1, pending: 0 }, report.retention_totals)
  end

  private

  def signup(key, source)
    user = User.create!(email_address: "#{key}@example.com", oauth_provider: "google", oauth_uid: "marketing-#{key}")
    visit = create_visit(user: user, source: source)
    user.marketing_events.find_by!(name: "signup").update!(marketing_visit: visit)
    user
  end

  def create_visit(user: nil, source: "direct")
    MarketingVisit.create!(visitor_key: SecureRandom.uuid, user: user, source: source, medium: "social", campaign: "test", started_at: Time.current, last_seen_at: Time.current, landing_path: "/", platform: "web")
  end
end
