require "test_helper"
require "minitest/mock"
require_relative "../test_helpers/daily_practice_test_helper"

class AiAllowanceTest < ActionDispatch::IntegrationTest
  include DailyPracticeTestHelper

  setup do
    @question = question_for
    @calls = 0
    @translator = Object.new
    test = self
    @translator.define_singleton_method(:call) do |text:, mode:|
      test.count_call
      mode == "answer" ? { "english" => "I like tea.", "ipa" => "/aɪ laɪk ti/" } : { "translation" => "오늘 무엇이 당신을 웃게 했나요?" }
    end
    patch native_language_path, params: { native_language: "ko" }
  end

  def count_call
    @calls += 1
  end

  test "three active days each include all help modes and the fourth blocks paid calls and uploads" do
    sign_in_as(users(:korean_native))
    first_day = Date.current
    GeminiTranslation.stub(:new, -> { @translator }) do
      [ 0, 1, 4 ].each_with_index do |offset, index|
        travel_to(first_day.in_time_zone + offset.days + 12.hours) do
          @question = question_for
          2.times { get root_path; assert_select ".daily-meta", text: /무료 훈련 #{index + 1}\/3회/ }
          %w[example question answer].each do |mode|
            2.times { request_help(mode); assert_response :success }
          end
          submit_recording
          assert_response :created
          get root_path
          assert_select "h1", text: "잘했어요!"
        end
      end
      assert_equal 9, @calls, "Each mode is generated once per active day, not once per page view"
      travel_to(first_day.in_time_zone + 5.days + 12.hours) do
        generator = Object.new
        generator.define_singleton_method(:call) { |**| raise "Paywall must not generate a question" }
        GeminiQuestion.stub(:new, -> { generator }) do
          get root_path
          assert_response :success
          assert_select "h1", text: "무료 훈련 3회를 모두 이용했어요"
          assert_select "#daily-question", count: 0
          assert_select "button", text: /결제/, count: 0
        end
        @question = question_for
        request_help("answer")
        assert_response :payment_required
        assert_no_difference "DailyPractice.count" do
          submit_recording
          assert_response :payment_required
        end
        assert_equal 9, @calls
      end
    end
  end

  test "the same answer is replayed and a different answer keeps the first expression" do
    sign_in_as(users(:korean_native))
    GeminiTranslation.stub(:new, -> { @translator }) do
      2.times { request_help("answer"); assert_response :success }
      request_help("answer", text: "다른 말을 해볼게요.")
      assert_response :too_many_requests
      assert_select ".english-answer", text: "I like tea."
      get root_path
      assert_select ".english-answer", text: "I like tea."
      assert_equal 1, @calls
      submit_recording
      assert_response :created
    end
  end

  test "Korean midnight renews help once and counts a new training day" do
    sign_in_as(users(:korean_native))
    time = Time.zone.local(2026, 10, 20, 23, 59, 50)
    GeminiTranslation.stub(:new, -> { @translator }) do
      travel_to(time) do
        @question = question_for
        request_help("answer")
        assert_response :success
      end
      travel_to(time + 20.seconds) do
        request_help("answer")
        assert_response :unprocessable_entity, "Yesterday's token cannot use today's allowance"
        @question = question_for
        request_help("answer")
        assert_response :success
        get root_path
        assert_select ".daily-meta", text: /무료 훈련 2\/3회/
      end
      assert_equal 2, @calls
    end
  end

  test "guest days and help are claimed once and signing out cannot reset the trial" do
    GeminiTranslation.stub(:new, -> { @translator }) do
      request_help("answer")
      submit_recording
      2.times do
        get authenticate_by_token_google_oauth_sessions_path(token: users(:korean_native).signed_id(purpose: :native_auth))
      end
      request_help("answer")
      assert_response :success
      user = users(:korean_native)
      usage = AiUsage.find_by!(identity_key: AiUsage.send(:identity, "user", "#{user.oauth_provider}:#{user.oauth_uid}"))
      assert_equal [ Date.current ], usage.training_dates
      assert_equal 1, user.daily_practices.count
      delete session_path
      get root_path
      assert_redirected_to new_session_path
      request_help("answer")
      assert_response :unauthorized
      assert_equal 1, @calls
    end
  end

  test "clearing visitor cookies cannot bypass the anonymous daily network guard" do
    GeminiTranslation.stub(:new, -> { @translator }) do
      4.times do |index|
        cookies.delete("ai_visitor_id")
        request_help("answer")
        assert_response(index < 3 ? :success : :too_many_requests)
      end
      assert_equal 3, @calls
      travel 1.day do
        @question = question_for
        request_help("answer")
        assert_response :success
      end
    end
  end

  test "different signed-in accounts have their own trial and answers on the same browser and network" do
    GeminiTranslation.stub(:new, -> { @translator }) do
      [ users(:korean_native), users(:spanish_native) ].each do |user|
        get authenticate_by_token_google_oauth_sessions_path(token: user.signed_id(purpose: :native_auth))
        2.times { request_help("answer"); assert_response :success }
      end
      assert_equal 2, @calls
    end
  end

  test "invalid requests cost nothing and failed upstream attempts cannot loop" do
    sign_in_as(users(:korean_native))
    GeminiTranslation.stub(:new, -> { @translator }) do
      request_help("answer", text: "")
      assert_response :unprocessable_entity
      post language_help_path, params: { mode: "question", question_token: "forged" }
      assert_response :unprocessable_entity
      assert_equal 0, @calls
      @translator.define_singleton_method(:call) { |**| raise GeminiText::Unavailable, "offline" }
      request_help("answer")
      assert_response :service_unavailable
      request_help("answer")
      assert_response :too_many_requests
    end
  end

  test "saved practice dates count toward the trial without using up the final day early" do
    user = users(:korean_native)
    [ 2.days.ago.to_date, Date.yesterday ].each { |date| complete_practice(user, date) }
    sign_in_as(user)
    get root_path
    assert_select ".daily-meta", text: /무료 훈련 3\/3회/
    submit_recording
    assert_response :created
    travel 1.day do
      get root_path
      assert_select "h1", text: "무료 훈련 3회를 모두 이용했어요"
    end
  end

  test "a guest can record on the next day before yesterday's audio expires" do
    travel_to(Time.zone.local(2026, 10, 20, 23, 59)) do
      @question = question_for
      submit_recording
      assert_response :created
    end
    travel_to(Time.zone.local(2026, 10, 21, 0, 1)) do
      @question = question_for
      assert_difference "DailyPractice.count" do
        submit_recording
        assert_response :created
      end
    end
  end

  test "deleting an account clears English responses while retaining the used trial dates" do
    user = users(:korean_native)
    usage = AiUsage.start_day!(user: user, visitor_id: nil)
    AiUsage.fetch!(usage: usage, mode: "answer", input: "hello") { { "english" => "Hello", "ipa" => "/həˈloʊ/" } }
    AiUsage.clear_user_responses!(user)
    assert_empty usage.reload.help_data
    assert_equal [ Date.current ], usage.training_dates
  end

  test "an exhausted account cannot extend its trial by claiming another guest session" do
    user = users(:korean_native)
    [ 3.days.ago.to_date, 2.days.ago.to_date, Date.yesterday ].each do |date|
      AiUsage.start_day!(user: user, visitor_id: nil, date: date)
    end
    submit_recording
    guest_practice = DailyPractice.last
    get authenticate_by_token_google_oauth_sessions_path(token: user.signed_id(purpose: :native_auth))
    assert_nil guest_practice.reload.user_id
    follow_redirect!
    assert_select "h1", text: "무료 훈련 3회를 모두 이용했어요"
    GeminiTranslation.stub(:new, -> { @translator }) do
      request_help("answer")
      assert_response :payment_required
      assert_equal 0, @calls
    end
  end

  private

  def request_help(mode, text: "차를 좋아해요.")
    post language_help_path, params: { mode: mode, question_token: @question.signed_id(purpose: :daily_question), input_text: text }
  end

  def submit_recording
    post daily_practice_path, params: { question_token: @question.signed_id(purpose: :daily_question), daily_practice: { audio: audio_upload, duration_ms: 2000 } }, headers: { "Accept" => "application/json" }
  end
end
