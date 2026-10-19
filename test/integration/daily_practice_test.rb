require "test_helper"
require_relative "../test_helpers/daily_practice_test_helper"

class DailyPracticeAccessTest < ActionDispatch::IntegrationTest
  include DailyPracticeTestHelper

  setup do
    @user = users(:english_native)
    question_for
    sign_in_as(@user)
  end

  test "login opens today's question without onboarding or profile" do
    get root_path
    assert_response :success
    assert_select "#daily-question", text: question_for.question
    %w[display_name gender age_group age_confirmed_at onboarding_completed_at].each { |column| assert_not User.column_names.include?(column) }
    assert_select "a[href='/profile']", count: 0
    assert_select ".recording-controls button[aria-label='녹음 시작'][hidden][disabled]", count: 1
    assert_select ".record-translation-prompt", text: /먼저 한국어로/
  end

  test "submitting once completes today and retries do not create or replace recordings" do
    assert_difference "DailyPractice.count", 1 do
      2.times do
        post daily_practice_path, params: valid_params
        assert_response :created
      end
    end
    practice = @user.daily_practices.sole
    assert practice.audio.attached?
    assert_equal Date.current, practice.practiced_on
    get root_path
    assert_select "h1", text: "잘했어요!"
    assert_select "button[aria-label='녹음 시작']", count: 0
    assert_equal 1, @user.streak
    get audio_daily_practice_path
    assert_response :success
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end

  test "an empty upload or a forged completion cannot earn a streak" do
    assert_no_difference "DailyPractice.count" do
      post daily_practice_path, params: valid_params.merge(daily_practice: { duration_ms: 2000, completed_at: Time.current })
      assert_response :unprocessable_entity
      post daily_practice_path, params: valid_params.merge(question_token: "forged")
      assert_response :conflict
    end
  end

  test "old question cannot be submitted after Seoul midnight and tomorrow opens a new question" do
    travel_to Time.zone.local(2026, 10, 18, 23, 59, 59) do
      old_params = valid_params
      travel 2.seconds
      assert_equal Date.new(2026, 10, 19), Date.current
      assert_no_difference "DailyPractice.count" do
        post daily_practice_path, params: old_params
        assert_response :conflict
      end
      question_for
      get root_path
      assert_select "#daily-question"
      post daily_practice_path, params: valid_params
      assert_response :created
      assert_equal Date.current, @user.daily_practices.sole.practiced_on
    end
  end

  test "recordings are private and require authentication" do
    complete_practice(@user)
    sign_out
    get audio_daily_practice_path
    assert_redirected_to new_session_path
    sign_in_as(users(:korean_native))
    get audio_daily_practice_path
    assert_response :not_found
  end

  test "deleted features have no routes" do
    %w[/onboarding /profile /rooms /feedbacks /room_reception /community_rules].each do |path|
      assert_raises(ActionController::RoutingError) { Rails.application.routes.recognize_path(path) }
    end
  end

  test "settings has only account controls and deletion removes recordings" do
    complete_practice(@user)
    get settings_path
    assert_response :success
    assert_select "a[href='/profile']", count: 0
    get confirm_account_deletion_path
    assert_response :success
    assert_difference "User.count", -1 do
      delete account_path
    end
    assert_equal 0, DailyPractice.where(user_id: @user.id).count
    assert_redirected_to new_session_path
  end

  test "completion shows the next reset at Seoul midnight" do
    travel_to Time.zone.local(2026, 10, 18, 23, 59, 30) do
      complete_practice(@user)
      get root_path
      assert_response :success
      assert_select '[data-reset-countdown-at-value="2026-10-19T00:00:00+09:00"]'
      assert_select ".next-practice-heading", text: /내일 00:00.*한국 시간/
      assert_select ".next-practice-clock", text: "00:00:30"
    end
  end

  private

  def valid_params
    prepare_recording_translation
    { question_token: question_for.signed_id(purpose: :daily_question), daily_practice: { audio: audio_upload, duration_ms: 2000 } }
  end
end
