require "application_system_test_case"
require_relative "../test_helpers/daily_practice_test_helper"

class AdminUsersPageTest < ApplicationSystemTestCase
  include DailyPracticeTestHelper
  driven_by :selenium, using: :headless_chrome, screen_size: [1280, 900]

  test "administrator reads and searches user metrics" do
    admin = users(:english_native)
    admin.update!(email_address: "porporpor020202@gmail.com")
    complete_practice(users(:korean_native))
    question_for
    sign_in(user: admin)
    visit admin_path
    assert_selector "h1", text: "사용자 현황"
    assert_text "korean@example.com"
    assert_text "완료 ✓"
    page.save_screenshot(Rails.root.join("tmp/admin-users.png"))
    fill_in "이메일 검색", with: "korean@example.com"
    click_button "검색"
    assert_selector ".admin-table tbody tr", count: 1
    assert_text "korean@example.com"
    click_link "녹음 보기"
    assert_selector "h1", text: "연습 녹음"
    assert_text "What made you smile today?"
    click_button "녹음 재생", enable_aria_label: true
    assert_selector "audio", visible: :all do |audio|
      audio.evaluate_script("this.readyState >= 2")
    end
    assert_selector ".help-error", visible: :hidden
    assert page.evaluate_script("document.querySelector('audio').error === null")
    page.save_screenshot(Rails.root.join("tmp/admin-recordings.png"))
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end
end
