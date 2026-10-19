require "application_system_test_case"
require_relative "../test_helpers/daily_practice_test_helper"

class MarketingDashboardTest < ApplicationSystemTestCase
  include DailyPracticeTestHelper
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 900 ] do |options|
    options.add_argument "--mute-audio"
    options.add_argument "--use-fake-device-for-media-stream"
    options.add_argument "--use-fake-ui-for-media-stream"
  end

  test "recording before upload is reported and admin can filter campaigns and build a real link" do
    question_for
    visit root_path(utm_source: "youtube", utm_medium: "social", utm_campaign: "short-01")
    choose "한국어", allow_label_click: true
    click_button "계속하기"
    translate_in_browser
    click_button "녹음 시작", enable_aria_label: true
    assert_selector '[data-daily-practice-target="timer"]', text: "00:02", wait: 5
    click_button "녹음 끝내기", enable_aria_label: true
    assert_button "전송"
    assert_selector "body" do
      MarketingEvent.where(name: "recording_completed").exists?
    end
    assert_equal 0, DailyPractice.count, "A local recording must be distinguishable from a saved upload."

    admin = users(:english_native)
    admin.update!(email_address: User::ADMIN_EMAIL)
    Capybara.using_session(:marketing_admin) do
      sign_in(user: admin)
      visit admin_path
      click_link "마케팅 지표"
      assert_selector "h1", text: "마케팅 지표"
      assert_selector ".marketing-sources tbody tr", text: "short-01"
      assert_selector ".marketing-stage", text: /기기에서 녹음 완료\s+1\s+100.0%/
      assert_selector ".marketing-stage", text: /녹음 전송 완료\s+0\s+0.0%/
      assert_text "1개는 종료일까지 신규 가입으로 이어지지 않았습니다."
      page.save_screenshot(Rails.root.join("tmp/admin-marketing-desktop.png"))

      fill_in "글 이름", with: "한 문장 소개"
      fill_in "링크 구분 · 선택", with: "comment"
      url = URI.parse(find_field("추적 링크", enable_aria_label: true).value)
      assert_equal "sayonething.net", url.host
      assert_equal({ "utm_source" => "youtube", "utm_medium" => "social", "utm_campaign" => "한 문장 소개", "utm_content" => "comment" }, URI.decode_www_form(url.query).to_h)
      page.execute_script("Object.defineProperty(navigator, 'clipboard', {configurable: true, value: {writeText: async text => { window.copiedCampaign = text }}})")
      click_button "링크 복사"
      assert_text "복사했어요. 홍보 글에 붙여넣으세요."
      assert_equal url.to_s, page.evaluate_script("window.copiedCampaign")

      fill_in "홍보 글 이름", with: "missing-post"
      click_button "조회"
      assert_selector ".marketing-sources td", text: "이 조건의 방문 기록이 없습니다."
      fill_in "홍보 글 이름", with: "short-01"
      click_button "조회"
      assert_selector ".marketing-sources tbody tr", text: "short-01"
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
      assert page.evaluate_script("document.documentElement.scrollWidth <= innerWidth")
      assert page.evaluate_script("document.querySelector('main').scrollHeight > document.querySelector('main').clientHeight")
      page.save_screenshot(Rails.root.join("tmp/admin-marketing-mobile.png"))
      page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    end
  end
end
