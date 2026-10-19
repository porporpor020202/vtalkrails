require "test_helper"
require_relative "../test_helpers/daily_practice_test_helper"

class PracticeSentenceTest < ActionDispatch::IntegrationTest
  include DailyPracticeTestHelper

  setup do
    patch native_language_path, params: { native_language: "ko" }
    question_for
  end

  test "uploading without answer translation is blocked even with a client supplied sentence" do
    get root_path
    assert_select ".record-button[hidden][disabled]"
    assert_select ".record-translation-prompt", text: /먼저 한국어로/
    assert_no_difference "DailyPractice.count" do
      upload
      assert_response :unprocessable_entity
      assert_equal I18n.t("ui.translate_before_recording"), response.parsed_body["error"]
    end
    translator = Object.new
    translator.define_singleton_method(:call) { |**| { "translation" => "오늘 무엇이 당신을 웃게 했나요?" } }
    GeminiTranslation.stub(:new, -> { translator }) do
      post language_help_path, params: { mode: "question", question_token: question_for.signed_id(purpose: :daily_question) }
      assert_response :success
    end
    assert_no_difference "DailyPractice.count" do
      upload
      assert_response :unprocessable_entity
    end
  end

  test "a guest's translated sentence survives cache cleanup and login without trusting the client" do
    prepare_recording_translation(english: "I enjoyed a warm latte.")
    upload
    assert_response :created
    practice = DailyPractice.last
    assert_nil practice.user_id
    assert_equal "I enjoyed a warm latte.", practice.english_sentence
    AiUsage.update_all(help_data: {}, help_on: nil)
    get root_path
    assert_select ".completion-sentences p[lang=en]", text: practice.english_sentence
    get authenticate_by_token_google_oauth_sessions_path(token: users(:korean_native).signed_id(purpose: :native_auth))
    follow_redirect!
    assert_equal users(:korean_native).id, practice.reload.user_id
    assert_equal [ practice.english_sentence ], card_data.fetch("sentences")
    assert_select ".completion-sentences p[lang=en]", text: practice.english_sentence
  end

  test "recording retries preserve the saved sentence even after the AI cache is removed" do
    user = users(:korean_native)
    sign_in_as(user)
    prepare_recording_translation(english: "I met a friend.")
    upload
    assert_response :created
    practice = user.daily_practices.sole
    blob_id = practice.audio.blob.id
    AiUsage.clear_user_responses!(user)
    assert_no_difference "DailyPractice.count" do
      upload
      assert_response :created
    end
    assert_equal blob_id, practice.reload.audio.blob.id
    assert_equal "I met a friend.", practice.english_sentence
    get root_path
    assert_equal [ "I met a friend." ], card_data.fetch("sentences")
  end

  test "the bonus needs its own translation and both sentences appear after completion" do
    user = users(:korean_native)
    practice = complete_practice(user, Date.current, english_sentence: "I had a good day.")
    bonus = BonusPractice.create!(daily_practice: practice, question: "What is your favorite color?", source: "sample", shared_at: Time.current)
    sign_in_as(user)
    prepare_recording_translation
    assert_no_difference "ActiveStorage::Attachment.count" do
      upload(bonus: bonus)
      assert_response :unprocessable_entity
    end
    assert_not bonus.reload.completed?
    prepare_recording_translation(question_token: bonus.signed_id(purpose: :bonus_practice), english: "I like green.")
    upload(bonus: bonus)
    assert_response :created
    assert_equal "I like green.", bonus.reload.english_sentence
    AiUsage.clear_user_responses!(user)
    get root_path
    assert_select ".completion-sentences p", count: 2
    assert_equal [ "I had a good day.", "I like green." ], card_data.fetch("sentences")
  end

  test "yesterday's translation never unlocks today's microphone or upload" do
    travel_to(Time.zone.local(2026, 10, 20, 23, 59)) { prepare_recording_translation }
    travel_to(Time.zone.local(2026, 10, 21, 0, 1)) do
      question_for
      get root_path
      assert_select ".record-button[hidden][disabled]"
      assert_select ".english-answer", count: 0
      upload
      assert_response :unprocessable_entity
    end
  end

  test "a failed translation cannot unlock recording" do
    translator = Object.new
    translator.define_singleton_method(:call) { |**| raise GeminiText::Unavailable, "unavailable" }
    GeminiTranslation.stub(:new, -> { translator }) do
      post language_help_path, params: { mode: "answer", question_token: question_for.signed_id(purpose: :daily_question), input_text: "차를 좋아해요." }
      assert_response :service_unavailable
    end
    upload
    assert_response :unprocessable_entity
    assert_equal 0, DailyPractice.count
  end

  test "legacy recordings with no saved text do not display a guessed sentence" do
    user = users(:korean_native)
    complete_practice(user, Date.current, english_sentence: nil)
    sign_in_as(user)
    get root_path
    assert_select ".completion-sentences", count: 0
    assert_empty card_data.fetch("sentences")
  end

  private

  def upload(bonus: nil)
    token = bonus ? bonus.signed_id(purpose: :bonus_practice) : question_for.signed_id(purpose: :daily_question)
    post(bonus ? recording_bonus_practice_path : daily_practice_path, params: { question_token: token, daily_practice: { audio: audio_upload, duration_ms: 2000, english_sentence: "Forged client sentence." } }, headers: { "Accept" => "application/json" })
  end

  def card_data
    element = css_select("[data-practice-share-card-value]").sole
    JSON.parse(element["data-practice-share-card-value"])
  end
end
