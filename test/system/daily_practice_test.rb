require "application_system_test_case"
require "minitest/mock"
require_relative "../test_helpers/daily_practice_test_helper"

class DailyPracticeFlowTest < ApplicationSystemTestCase
  include DailyPracticeTestHelper

  driven_by :selenium, using: :headless_chrome, screen_size: [ 390, 844 ] do |options|
    options.add_argument "--mute-audio"
    options.add_argument "--use-fake-device-for-media-stream"
    options.add_argument "--use-fake-ui-for-media-stream"
  end

  setup do
    @user = users(:english_native)
    question_for
    sign_in(user: @user)
  end

  teardown { page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") }

  test "record submit celebrate and reload without earning a second completion" do
    assert_selector "#daily-question"
    assert_no_text "Select your native language"
    assert_no_button "질문 듣기"
    click_button "녹음 시작", enable_aria_label: true
    assert_selector '[data-daily-practice-target="timer"]', text: "00:02", wait: 5
    click_button "녹음 끝내기", enable_aria_label: true
    assert_selector '.recording-preview audio[src^="blob:"]', visible: :all
    click_button "다시 녹음"
    assert_button "녹음 시작", enable_aria_label: true
    click_button "녹음 시작", enable_aria_label: true
    assert_selector '[data-daily-practice-target="timer"]', text: "00:02", wait: 5
    click_button "녹음 끝내기", enable_aria_label: true
    click_button "전송"
    assert_selector "h1", text: "잘했어요!"
    assert_text "오늘 완료"
    assert_selector ".completion-count", text: /연속\s+1\s*일/
    assert_equal 1, @user.daily_practices.count
    page.refresh
    assert_selector "h1", text: "잘했어요!"
    assert_no_button "녹음 시작", enable_aria_label: true
    page.save_screenshot(Rails.root.join("tmp/daily-practice-complete.png"))
  end

  test "microphone denial can be retried and never earns completion" do
    page.execute_script("navigator.mediaDevices.getUserMedia = async () => { throw new DOMException('Denied', 'NotAllowedError') }")
    click_button "녹음 시작", enable_aria_label: true
    assert_selector '[role="alert"]', text: "마이크 권한이 필요해요"
    assert_button "녹음 시작", enable_aria_label: true, disabled: false
    assert_equal 0, @user.daily_practices.count
  end

  test "mobile layout has no horizontal overflow or retired controls" do
    [ 320, 390, 1400 ].each do |width|
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 844, deviceScaleFactor: 1, mobile: width < 500)
      visit root_path
      assert_selector "#daily-question"
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
      assert_no_selector "a[href='/profile']"
      assert_no_selector "button[aria-label='Drop a voice']"
    end
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    page.save_screenshot(Rails.root.join("tmp/daily-practice-question.png"))
  end
  test "question translation and Korean answer help work inside Turbo frames" do
    translator = Object.new
    translator.define_singleton_method(:call) do |text:, mode:|
      mode == "answer" ? { "english" => "I like warm lattes.", "ipa" => "/aɪ laɪk wɔrm ˈlɑteɪz/" } : { "translation" => mode == "example" ? "친구의 농담에 웃었어요." : "오늘 무엇이 당신을 웃게 했나요?" }
    end
    GeminiTranslation.stub(:new, -> { translator }) do
      visit root_path
      click_button "번역 보기"
      assert_text "오늘 무엇이 당신을 웃게 했나요?"
      assert_no_selector "dialog"
      assert_no_button "이거 영어로 뭐라 말해요?"
      assert_selector 'textarea[placeholder="예: 친구의 농담에 웃었어요."]'
      fill_in "하고 싶은 말을 한국어로 적어주세요. 영어로 먼저 확인하고 내뱉어보세요!", with: "따뜻한 라테를 좋아해요."
      click_button "영어로 알아보기"
      assert_selector ".english-answer", text: "I like warm lattes."
      assert_selector ".ipa-answer", text: "/aɪ laɪk wɔrm ˈlɑteɪz/"
      assert_no_button "발음 듣기"
      assert_text "What made you smile today?"
      page.save_screenshot(Rails.root.join("tmp/daily-language-help.png"))
      click_button "녹음 시작", enable_aria_label: true
      assert_selector ".english-answer", text: "I like warm lattes."
      assert_button "녹음 끝내기", enable_aria_label: true
      assert_selector '[data-daily-practice-target="timer"]', text: "00:02", wait: 5
      click_button "녹음 끝내기", enable_aria_label: true
      assert_button "녹음 재생", enable_aria_label: true
      assert_no_selector "audio[controls]"
      click_button "녹음 재생", enable_aria_label: true
      assert_button "녹음 정지", enable_aria_label: true
      assert_selector '[data-recording-player-target="stop"]'
      assert_no_selector '[data-recording-player-target="play"]'
      assert_selector ".playback-gauge" do |gauge|
        gauge["aria-valuenow"].to_i >= 25
      end
      click_button "녹음 정지", enable_aria_label: true
      assert_selector '.playback-gauge[aria-valuenow="0"]'
      click_button "녹음 재생", enable_aria_label: true
      assert_selector '.playback-gauge[aria-valuenow="100"]', wait: 5
      assert_button "녹음 재생", enable_aria_label: true
      page.save_screenshot(Rails.root.join("tmp/recording-inside-help.png"))
      click_button "전송"
      assert_selector "h1", text: "잘했어요!"
      assert_equal 1, @user.daily_practices.count
    end
  end
  test "completion countdown reveals the next question button when time is up" do
    complete_practice(@user)
    visit root_path
    assert_selector ".next-practice-clock", text: /\d{2}:\d{2}:\d{2}/
    assert_text "내일 00:00 · 한국 시간"
    assert_no_link "새 질문 열기"
    page.execute_script(<<~JS)
      const timer = document.querySelector('[data-controller="reset-countdown"]');
      const now = Date.now();
      timer.setAttribute('data-reset-countdown-at-value', new Date(now + 1000).toISOString());
      timer.setAttribute('data-reset-countdown-now-value', new Date(now).toISOString());
    JS
    assert_link "새 질문 열기", wait: 4
    assert_no_selector ".next-practice-clock"
  end
end
