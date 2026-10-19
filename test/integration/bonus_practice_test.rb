require "test_helper"
require "minitest/mock"
require_relative "../test_helpers/daily_practice_test_helper"

class BonusPracticeTest < ActionDispatch::IntegrationTest
  include DailyPracticeTestHelper

  setup do
    @user = users(:korean_native)
    @practice = complete_practice(@user)
    sign_in_as(@user)
    @calls = 0
    test = self
    @generator = Object.new
    @generator.define_singleton_method(:call) do |**|
      test.count_call
      "What is your favorite color?"
    end
  end

  def count_call
    @calls += 1
  end

  test "sharing unlocks one bonus question without another trial day" do
    GeminiQuestion.stub(:new, -> { @generator }) do
      assert_difference "BonusPractice.count", 1 do
        2.times { unlock; assert_response :created }
      end
    end
    assert_equal 1, @calls
    bonus = @practice.reload.bonus_practice
    assert_not_equal @practice.daily_question.question, bonus.question
    assert_not bonus.completed?
    get bonus_practice_path
    assert_select "#daily-question", text: bonus.question
    assert_select "[data-daily-practice-endpoint-value=?]", recording_bonus_practice_path
    get root_path
    assert_select "a", text: "추가 연습 이어하기"
    assert_equal [ Date.current ], usage.training_dates
    assert_equal 1, @user.streak
  end

  test "bonus recording is saved once and never increases the daily streak or allows a third sentence" do
    GeminiQuestion.stub(:new, -> { @generator }) { unlock }
    bonus = @practice.reload.bonus_practice
    assert_no_difference "DailyPractice.count" do
      2.times { record_bonus(bonus); assert_response :created }
    end
    assert bonus.reload.completed?
    assert bonus.audio.attached?
    assert_equal 1, @user.streak
    assert_equal 1, @user.daily_practices.count
    assert_equal [ Date.current ], usage.training_dates
    get root_path
    assert_select ".completion-count", text: /연속\s+1\s*일/
    assert_select ".share-incentive", text: /두 문장 완료/
    assert_select "button", text: "친구에게 공유하기", count: 1
    assert_no_difference "BonusPractice.count" do
      unlock
      assert_response :created
      assert_equal root_path, response.parsed_body.fetch("redirect_url")
    end
    get bonus_practice_path
    assert_redirected_to root_path
  end

  test "bonus help has its own single daily answer and requires an owned unlocked bonus" do
    translator = Object.new
    calls = 0
    translator.define_singleton_method(:call) do |**|
      calls += 1
      { "english" => "I like green.", "ipa" => "/aɪ laɪk ɡrin/" }
    end
    GeminiQuestion.stub(:new, -> { @generator }) { unlock }
    bonus = @practice.reload.bonus_practice
    GeminiTranslation.stub(:new, -> { translator }) do
      post language_help_path, params: { mode: "answer", question_token: @practice.daily_question.signed_id(purpose: :daily_question), input_text: "초록색이 좋아요" }
      assert_response :success
      2.times do
        post language_help_path, params: { mode: "answer", question_token: bonus.signed_id(purpose: :bonus_practice), input_text: "초록색이 좋아요" }
        assert_response :success
        assert_select 'input[name="question_token"][value=?]', bonus.signed_id(purpose: :bonus_practice)
      end
      post language_help_path, params: { mode: "answer", question_token: bonus.signed_id(purpose: :bonus_practice), input_text: "노란색도 좋아요" }
      assert_response :too_many_requests
      assert_select ".english-answer", text: "I like green."
      sign_in_as(users(:spanish_native))
      post language_help_path, params: { mode: "answer", question_token: bonus.signed_id(purpose: :bonus_practice), input_text: "다른 계정" }
      assert_response :unprocessable_entity
      assert_equal 2, calls
    end
  end

  test "a forged share or another person's completion cannot grant a reward" do
    assert_no_difference "BonusPractice.count" do
      post bonus_practice_path, params: { practice_token: "forged" }, as: :json
      assert_response :conflict
      sign_in_as(users(:spanish_native))
      unlock
      assert_response :conflict
      sign_out
      unlock
      assert_redirected_to new_session_path
    end
    assert_equal 0, @calls
  end

  test "the bonus expires at Seoul midnight and a malformed recording cannot complete it" do
    GeminiQuestion.stub(:new, -> { @generator }) { unlock }
    bonus = @practice.reload.bonus_practice
    post recording_bonus_practice_path, params: { question_token: bonus.signed_id(purpose: :bonus_practice), daily_practice: { duration_ms: 2000 } }, as: :json
    assert_response :unprocessable_entity
    assert_not bonus.reload.completed?
    travel 1.day do
      unlock
      assert_response :conflict
      record_bonus(bonus)
      assert_response :conflict
      get bonus_practice_path
      assert_redirected_to root_path
    end
    assert_not bonus.reload.completed?
  end

  test "people on the same day share the same bonus question without repeated Gemini calls" do
    second = complete_practice(users(:spanish_native))
    GeminiQuestion.stub(:new, -> { @generator }) do
      unlock
      sign_in_as(users(:spanish_native))
      post bonus_practice_path, params: { practice_token: second.signed_id(purpose: :share_bonus) }, as: :json
      assert_response :created
    end
    assert_equal 1, @calls
    assert_equal @practice.reload.bonus_practice.question, second.reload.bonus_practice.question
  end

  test "deleting an account also deletes the bonus recording and administrators can listen before deletion" do
    GeminiQuestion.stub(:new, -> { @generator }) { unlock }
    bonus = @practice.reload.bonus_practice
    record_bonus(bonus)
    get bonus_audio_admin_user_path(@user, practice_id: bonus.id)
    assert_response :forbidden
    admin = users(:english_native)
    admin.update!(email_address: "porporpor020202@gmail.com")
    sign_in_as(admin)
    get admin_user_path(@user)
    assert_select ".admin-recording", count: 2
    get bonus_audio_admin_user_path(@user, practice_id: bonus.id)
    assert_response :success
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_equal File.binread(Rails.root.join("test/fixtures/files/practice.wav")), response.body
    get bonus_audio_admin_user_path(admin, practice_id: bonus.id)
    assert_response :not_found
    sign_in_as(@user)
    delete account_path
    assert_not BonusPractice.exists?(bonus.id)
    assert_not ActiveStorage::Attachment.exists?(record_type: "BonusPractice", record_id: bonus.id)
  end

  test "Gemini failure still unlocks a different clearly labeled sample" do
    @generator.define_singleton_method(:call) { |**| raise GeminiQuestion::Unavailable, "offline" }
    GeminiQuestion.stub(:new, -> { @generator }) { unlock }
    assert_response :created
    bonus = @practice.reload.bonus_practice
    assert_equal "sample", bonus.source
    assert_not_equal @practice.daily_question.question, bonus.question
    get bonus_practice_path
    assert_select ".question-label", text: "샘플 질문"
  end

  private

  def unlock
    post bonus_practice_path, params: { practice_token: @practice.signed_id(purpose: :share_bonus) }, as: :json
  end

  def record_bonus(bonus)
    prepare_recording_translation(question_token: bonus.signed_id(purpose: :bonus_practice), english: "I like green.") if bonus.asked_on == Date.current && !bonus.reload.completed?
    post recording_bonus_practice_path, params: { question_token: bonus.signed_id(purpose: :bonus_practice), daily_practice: { audio: audio_upload, duration_ms: 2000 } }, headers: { "Accept" => "application/json" }
  end

  def usage
    AiUsage.start_day!(user: @user, visitor_id: nil)
  end
end
