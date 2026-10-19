require "test_helper"
require_relative "../test_helpers/daily_practice_test_helper"

class GuestPracticeTest < ActionDispatch::IntegrationTest
  include DailyPracticeTestHelper

  setup { question_for }

  test "a visitor starts with the question and can complete before signing in" do
    get root_path
    assert_response :success
    assert_select "#daily-question"
    assert_select "a[href=?]", settings_path, count: 0
    assert_difference "DailyPractice.count", 1 do
      2.times { submit_recording; assert_response :created }
    end
    assert_nil DailyPractice.last.user_id
    get root_path
    assert_select "h1", text: "잘했어요!"
    assert_select "a[href=?]", new_session_path, text: "이 기록을 저장할까요?"
    get new_session_path
    assert_select ".sign-in-description", text: "첫 연습 기록을 저장하세요."
  end

  test "login claims the exact recording once and shows confirmation" do
    submit_recording
    practice = DailyPractice.last
    blob_id = practice.audio.blob.id
    user = users(:english_native)
    assert_no_difference "DailyPractice.count" do
      login(user)
    end
    assert_equal user.id, practice.reload.user_id
    assert_equal blob_id, practice.audio.blob.id
    follow_redirect!
    assert_select '[role=status]', text: /첫 연습 기록이 저장됐어요/
    assert_select ".completion-count", text: /연속\s+1\s*일/
    ExpireGuestPracticeJob.perform_now(practice.id)
    assert DailyPractice.exists?(practice.id)
  end

  test "a different browser cannot claim or listen to a guest recording" do
    submit_recording
    guest = DailyPractice.last
    another = open_session
    another.get audio_daily_practice_path
    assert_equal 302, another.response.status
    another.get authenticate_by_token_google_oauth_sessions_path(token: users(:korean_native).signed_id(purpose: :native_auth))
    assert_nil guest.reload.user_id
  end

  test "existing completion is preserved when signing in with a guest recording" do
    user = users(:english_native)
    original = complete_practice(user)
    submit_recording
    guest_id = DailyPractice.last.id
    login(user)
    assert_equal [original.id], user.daily_practices.pluck(:id)
    assert_not DailyPractice.exists?(guest_id)
  end

  test "expired guest recording is removed and invalid uploads cannot complete" do
    post daily_practice_path, params: { question_token: question_for.signed_id(purpose: :daily_question), daily_practice: { duration_ms: 2000 } }
    assert_response :unprocessable_entity
    assert_equal 0, DailyPractice.count
    submit_recording
    ExpireGuestPracticeJob.perform_now(DailyPractice.last.id)
    get root_path
    assert_select "#daily-question"
  end

  private

  def submit_recording
    post daily_practice_path, params: { question_token: question_for.signed_id(purpose: :daily_question), daily_practice: { audio: audio_upload, duration_ms: 2000 } }
  end

  def login(user)
    get authenticate_by_token_google_oauth_sessions_path(token: user.signed_id(purpose: :native_auth))
    assert_redirected_to root_url
  end
end
