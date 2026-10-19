require "application_system_test_case"
require "minitest/mock"
require_relative "../test_helpers/daily_practice_test_helper"

class AiAllowanceFlowTest < ApplicationSystemTestCase
  include DailyPracticeTestHelper

  driven_by :selenium, using: :headless_chrome, screen_size: [ 390, 844 ] do |options|
    options.add_argument "--mute-audio"
    options.add_argument "--use-fake-device-for-media-stream"
    options.add_argument "--use-fake-ui-for-media-stream"
  end

  test "a second expression is blocked but the first stays visible while recording and completing" do
    question = question_for
    cache = ActiveSupport::Cache::MemoryStore.new
    cache.write([ "question-example", :ko, question.id, question.updated_at.to_i ], "저는 친구와 이야기했어요.")
    calls = 0
    translator = Object.new
    translator.define_singleton_method(:call) do |**|
      calls += 1
      { "english" => "I talked with a friend. #{calls}", "ipa" => "/aɪ tɔkt wɪð ə frɛnd/" }
    end
    Rails.stub(:cache, cache) do
      GeminiTranslation.stub(:new, -> { translator }) do
        sign_in(user: users(:korean_native))
        fill_in "input_text", with: "친구와 이야기했어요."
        click_button "영어로 알아보기"
        assert_selector ".english-answer", text: "I talked with a friend. 1"
        fill_in "input_text", with: "다른 표현"
        click_button "영어로 알아보기"
        assert_selector ".help-error", text: "오늘의 영어 표현 도움말은 이미 사용했어요."
        assert_selector ".english-answer", text: "I talked with a friend. 1"
        assert_equal 1, calls
        click_button "녹음 시작", enable_aria_label: true
        assert_selector '[data-daily-practice-target="timer"]', text: "00:02", wait: 5
        click_button "녹음 끝내기", enable_aria_label: true
        click_button "전송"
        assert_selector "h1", text: "잘했어요!"
      end
    end
  end

  test "the fourth training day displays the trial notice without a purchase button" do
    user = users(:korean_native)
    [ 3.days.ago.to_date, 2.days.ago.to_date, Date.yesterday ].each do |date|
      AiUsage.start_day!(user: user, visitor_id: nil, date: date)
    end
    sign_in(user: user)
    assert_selector "h1", text: "무료 훈련 3회를 모두 이용했어요"
    assert_text "유료 훈련은 준비 중이에요."
    assert_no_selector "#daily-question"
    assert_no_button "녹음 시작", enable_aria_label: true
  end
end
