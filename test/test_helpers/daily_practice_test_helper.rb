require "minitest/mock"

module DailyPracticeTestHelper
  def question_for(date = Date.current)
    DailyQuestion.find_or_create_by!(asked_on: date) { |question| question.question = "What made you smile today?"; question.source = "sample" }
  end

  def audio_upload
    Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/practice.wav"), "audio/wav")
  end

  def complete_practice(user, date = Date.current, english_sentence: "I had a good day.")
    practice = user.daily_practices.build(daily_question: question_for(date), practiced_on: date, duration_ms: 2000, completed_at: date.in_time_zone + 12.hours, english_sentence: english_sentence)
    practice.audio.attach(io: File.open(Rails.root.join("test/fixtures/files/practice.wav")), filename: "practice.wav", content_type: "audio/wav")
    practice.save!
    practice
  end
  def prepare_recording_translation(question_token: question_for.signed_id(purpose: :daily_question), english: "I had a good day.")
    translator = Object.new
    translator.define_singleton_method(:call) { |**| { "english" => english, "ipa" => "/aɪ/" } }
    with_recording_translator(translator) do
      post language_help_path, params: { mode: "answer", question_token: question_token, input_text: "차를 좋아해요." }
    end
    assert_select ".english-answer", minimum: 1
  end

  def translate_in_browser(english: "I had a good day.")
    translator = Object.new
    translator.define_singleton_method(:call) do |mode:, **|
      mode == "answer" ? { "english" => english, "ipa" => "/aɪ/" } : { "translation" => "예시 답변" }
    end
    with_recording_translator(translator) do
      fill_in "input_text", with: "차를 좋아해요."
      click_button I18n.t("ui.translate_answer", locale: find("html")[:lang])
      assert_selector ".english-answer", text: english
    end
  end

  def with_recording_translator(translator, &block)
    if GeminiTranslation.respond_to?(:__minitest_stub__new, true)
      block.call
    else
      GeminiTranslation.stub(:new, -> { translator }, &block)
    end
  end

end
