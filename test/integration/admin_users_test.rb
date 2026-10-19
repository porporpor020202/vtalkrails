require "test_helper"
require_relative "../test_helpers/daily_practice_test_helper"

class AdminUsersTest < ActionDispatch::IntegrationTest
  include DailyPracticeTestHelper

  test "only the exact administrator email can access either provider" do
    get admin_path
    assert_redirected_to new_session_path
    %w[google apple].each do |provider|
      user = users(:english_native)
      user.update!(email_address: "porporpor020202@gmail.com", oauth_provider: provider)
      sign_in_as(user)
      get admin_path
      assert_response :success
      assert_equal "private, no-store", response.headers["Cache-Control"]
      get settings_path
      assert_select "a[href=?]", admin_path, text: "사용자 현황"
      sign_out
    end
    %w[porporpor020202@gmail.com.attacker.net someone@privaterelay.appleid.com other@gmail.com].each do |email|
      user = users(:korean_native)
      user.update!(email_address: email)
      sign_in_as(user)
      get admin_path
      assert_response :forbidden
      assert_not_includes response.body, "사용자 현황"
    end
  end

  test "dashboard shows Korean dates practice days streak and search without guest records" do
    travel_to Time.zone.local(2026, 10, 19, 12, 40) do
      admin = users(:english_native)
      admin.update!(email_address: "porporpor020202@gmail.com")
      user = users(:korean_native)
      user.update!(created_at: Time.utc(2026, 10, 19, 1, 3, 50))
      [Date.current, Date.yesterday, 4.days.ago.to_date].each { |date| complete_practice(user, date) }
      complete_practice(users(:spanish_native)).update!(user: nil)
      sign_in_as(admin)
      get admin_path, params: { q: user.email_address }
      assert_response :success
      assert_select ".admin-table tbody tr", count: 1
      assert_select "td", text: "2026.10.19 10:03"
      assert_select "td", text: "3일"
      assert_select "td", text: "2일"
      assert_select "td", text: "완료 ✓"
      assert_select ".admin-metrics strong", text: "1명", count: 2
      assert_select "td", text: "2026.10.19 12:00"
    end
  end

  test "last activity is tracked and throttled without changing profile update time" do
    user = users(:english_native)
    sign_in_as(user)
    original_updated_at = user.updated_at
    get settings_path
    first_seen = user.reload.last_active_at
    assert first_seen
    assert_equal original_updated_at, user.updated_at
    travel 2.minutes
    get settings_path
    assert_equal first_seen, user.reload.last_active_at
    travel 4.minutes
    get settings_path
    assert_operator user.reload.last_active_at, :>, first_seen
  end
end
