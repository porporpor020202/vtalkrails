require "application_system_test_case"
require "minitest/mock"
require_relative "../test_helpers/daily_practice_test_helper"

class MobileScrollingTest < ApplicationSystemTestCase
  include DailyPracticeTestHelper

  setup do
    question_for
    viewport(390, 844)
  end

  teardown { page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") }

  test "screens that fit stay still and long screens scroll only inside the app" do
    visit root_path
    assert_selector ".language-page"
    assert_no_scroll
    viewport(320, 568)
    assert_scrollable
    # The sticky continue button remains reachable on a short screen.
    page.execute_script("document.querySelector('main').scrollTop = 10000")
    choose "한국어", allow_label_click: true
    click_button "계속하기"
    assert_selector "#daily-question"
    assert_scrollable

    viewport(390, 844)
    visit new_session_path
    assert_selector ".sign-in-page"
    assert_no_scroll
    visit settings_path
    assert_selector ".settings-links"
    assert_no_scroll
    viewport(320, 568)
    visit privacy_path
    assert_selector ".simple-page h2", text: "AI와 음성"
    assert_scrollable
    page.execute_script("document.querySelector('main').scrollTop = 10000")
    assert_selector "a[href='mailto:privacy@sayonething.net']"
    assert page.evaluate_script("document.querySelector('main').scrollTop > 0")
    assert_equal 0, page.evaluate_script("window.scrollY")
  end

  test "expanded translations and a small keyboard viewport keep the input and microphone reachable" do
    sign_in(user: users(:korean_native))
    translator = Object.new
    translator.define_singleton_method(:call) { |mode:, **| mode == "answer" ? { "english" => "I had a good day.", "ipa" => "/aɪ/" } : { "translation" => "오늘 무엇이 당신을 웃게 했나요? " * 30 } }
    GeminiTranslation.stub(:new, -> { translator }) do
      click_button "번역 보기"
      assert_selector ".question-translation p"
      assert_scrollable
      viewport(390, 400)
      fill_in "input_text", with: "오늘 친구와 재미있게 이야기했어요."
      assert_equal "16px", page.evaluate_script("getComputedStyle(document.querySelector('textarea')).fontSize")
      assert_equal "contain", page.evaluate_script("getComputedStyle(document.querySelector('textarea')).overscrollBehaviorY")
      assert_scrollable
      translate_in_browser
      find_button("녹음 시작", enable_aria_label: true).scroll_to(:center)
      assert_button "녹음 시작", enable_aria_label: true
    end
  end

  test "completed practice fits and flash notices do not add an extra screen" do
    user = users(:korean_native)
    complete_practice(user)
    sign_in(user: user)
    assert_selector "h1", text: "잘했어요!"
    assert_no_scroll
    visit settings_path
    click_button "로그아웃"
    assert_selector ".flash", text: "로그아웃했어요."
    assert_no_scroll
  end

  private

  def viewport(width, height)
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: true)
  end

  def assert_shell_locked
    assert_equal "hidden", page.evaluate_script("getComputedStyle(document.documentElement).overflowY")
    assert_equal "none", page.evaluate_script("getComputedStyle(document.querySelector('main')).overscrollBehaviorY")
    assert page.evaluate_script("document.scrollingElement.scrollHeight <= innerHeight + 1"), "The document must not be a second scroll surface"
    assert page.evaluate_script("document.documentElement.scrollWidth <= innerWidth")
  end

  def assert_no_scroll
    assert_shell_locked
    assert page.evaluate_script("document.querySelector('main').scrollHeight <= document.querySelector('main').clientHeight + 1"), "Short screens should not have scrollable overflow"
  end

  def assert_scrollable
    assert_shell_locked
    assert page.evaluate_script("document.querySelector('main').scrollHeight > document.querySelector('main').clientHeight"), "Long content must remain scrollable"
  end
end
