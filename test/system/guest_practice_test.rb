require "application_system_test_case"
require_relative "../test_helpers/daily_practice_test_helper"

class GuestPracticeFlowTest < ApplicationSystemTestCase
  include DailyPracticeTestHelper

  driven_by :selenium, using: :headless_chrome, screen_size: [390, 844] do |options|
    options.add_argument "--mute-audio"
    options.add_argument "--use-fake-device-for-media-stream"
    options.add_argument "--use-fake-ui-for-media-stream"
  end

  test "first practice comes before login and its recording survives authentication" do
    question_for
    visit root_path
    choose "한국어", allow_label_click: true
    click_button "계속하기"
    assert_selector "#daily-question"
    assert_no_selector ".sign-in-page"
    assert_no_button "녹음 시작", enable_aria_label: true
    assert_selector ".record-translation-prompt", text: /먼저 한국어로/
    translate_in_browser
    assert_selector ".first-practice-hint", text: "아래 녹음 버튼을 눌러"
    assert_link "로그인"
    assert_no_selector ".streak-pill"
    click_button "녹음 시작", enable_aria_label: true
    assert_selector '[data-daily-practice-target="timer"]', text: "00:02", wait: 5
    assert_no_selector ".first-practice-hint"
    click_button "녹음 끝내기", enable_aria_label: true
    click_button "전송"
    assert_selector "h1", text: "잘했어요!"
    assert_link "이 기록을 저장할까요?"
    assert_no_selector ".completion-count, .completion-week"
    page.save_screenshot(Rails.root.join("tmp/guest-practice-complete.png"))
    practice = DailyPractice.last
    assert_nil practice.user_id
    assert_equal "I had a good day.", practice.english_sentence
    assert_selector ".completion-sentences p", text: "I had a good day."
    click_link "이 기록을 저장할까요?"
    assert_text "첫 연습 기록을 저장하세요."
    assert_text "구글로 시작하기"
    visit authenticate_by_token_google_oauth_sessions_path(token: users(:english_native).signed_id(purpose: :native_auth))
    assert_selector ".practice-saved", text: "첫 연습 기록이 저장됐어요."
    assert_equal users(:english_native).id, practice.reload.user_id
    assert_no_link "이 기록을 저장할까요?"
    page.save_screenshot(Rails.root.join("tmp/guest-practice-saved.png"))
  end
  test "a returning visitor logs in directly and sees saved days without a new recording" do
    user = users(:korean_native)
    [ Date.yesterday, Date.current ].each { |date| complete_practice(user, date) }
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    visit root_path
    assert_link "이미 계정이 있나요? 로그인"
    click_link "이미 계정이 있나요? 로그인"
    assert_selector ".sign-in-page"
    assert_no_difference "DailyPractice.count" do
      sign_in(user: user)
      assert_selector ".completion-count", text: /연속\s+2\s*일/
    end
    assert_no_link "로그인"
    assert_no_button "녹음 시작", enable_aria_label: true
    page.save_screenshot(Rails.root.join("tmp/returning-user-restored.png"))
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

end
