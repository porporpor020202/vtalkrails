require "test_helper"
require_relative "../test_helpers/daily_practice_test_helper"

class AdminRecordingsTest < ActionDispatch::IntegrationTest
  include DailyPracticeTestHelper

  setup do
    @admin = users(:english_native)
    @admin.update!(email_address: "porporpor020202@gmail.com")
    @user = users(:korean_native)
    @practice = complete_practice(@user)
  end

  test "administrator sees a user's dated questions and can play private recording bytes" do
    sign_in_as(@admin)
    get admin_path
    assert_select "a[href=?]", admin_user_path(@user), text: "녹음 보기"
    get admin_user_path(@user)
    assert_response :success
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_select ".admin-recording", count: 1
    assert_select "p[lang=en]", text: @practice.daily_question.question
    assert_select "audio[src=?]", audio_admin_user_path(@user, practice_id: @practice.id)
    get audio_admin_user_path(@user, practice_id: @practice.id)
    assert_response :success
    assert_equal @practice.audio.content_type, response.media_type
    assert_equal @practice.audio.download, response.body
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
  end

  test "unauthenticated and non-admin users cannot open pages or direct audio URLs" do
    [admin_user_path(@user), audio_admin_user_path(@user, practice_id: @practice.id)].each do |path|
      get path
      assert_redirected_to new_session_path
    end
    sign_in_as(@user)
    [admin_user_path(@user), audio_admin_user_path(@user, practice_id: @practice.id)].each do |path|
      get path
      assert_response :forbidden
    end
  end

  test "recording must belong to the selected user and guests are not exposed" do
    sign_in_as(@admin)
    get audio_admin_user_path(users(:spanish_native), practice_id: @practice.id)
    assert_response :not_found
    @practice.update!(user: nil)
    get audio_admin_user_path(@user, practice_id: @practice.id)
    assert_response :not_found
    get admin_user_path(@user)
    assert_select "audio", count: 0
    assert_select ".admin-note", text: "아직 저장된 녹음이 없습니다."
  end
end
