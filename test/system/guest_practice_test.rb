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
    assert_selector ".first-practice-hint", text: "아래 녹음 버튼을 눌러"
    click_button "녹음 시작", enable_aria_label: true
    assert_selector '[data-daily-practice-target="timer"]', text: "00:02", wait: 5
    assert_no_selector ".first-practice-hint"
    click_button "녹음 끝내기", enable_aria_label: true
    click_button "전송"
    assert_selector "h1", text: "잘했어요!"
    assert_link "이 기록을 저장할까요?"
    page.save_screenshot(Rails.root.join("tmp/guest-practice-complete.png"))
    practice = DailyPractice.last
    assert_nil practice.user_id
    click_link "이 기록을 저장할까요?"
    assert_text "첫 연습 기록을 저장하세요."
    assert_text "구글로 시작하기"
    visit authenticate_by_token_google_oauth_sessions_path(token: users(:english_native).signed_id(purpose: :native_auth))
    assert_selector ".practice-saved", text: "첫 연습 기록이 저장됐어요."
    assert_equal users(:english_native).id, practice.reload.user_id
    assert_no_link "이 기록을 저장할까요?"
    page.save_screenshot(Rails.root.join("tmp/guest-practice-saved.png"))
  end
end
