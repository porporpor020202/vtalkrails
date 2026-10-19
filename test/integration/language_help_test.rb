require "test_helper"
require "minitest/mock"

class LanguageHelpTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:english_native)
    @question = DailyQuestion.create!(asked_on: Date.current, question: "What do you like to drink?", source: "sample")
    sign_in_as(@user)
  end

  test "question translation uses the signed daily question" do
    translator = Object.new
    translator.define_singleton_method(:call) do |text:, mode:|
      raise "Wrong question" unless text == "What do you like to drink?" && mode == "question"
      { "translation" => "어떤 음료를 좋아하세요?" }
    end
    GeminiTranslation.stub(:new, -> { translator }) do
      post language_help_path, params: { mode: "question", question_token: @question.signed_id(purpose: :daily_question) }
      assert_response :success
      assert_select "turbo-frame#question-translation", text: /어떤 음료를 좋아하세요/
    end
  end

  test "Korean answer returns escaped English and IPA without completing practice" do
    translator = Object.new
    translator.define_singleton_method(:call) do |text:, mode:|
      { "english" => "I like warm lattes.", "ipa" => "/aɪ laɪk wɔrm ˈlɑteɪz/" }
    end
    GeminiTranslation.stub(:new, -> { translator }) do
      assert_no_difference "DailyPractice.count" do
        post language_help_path, params: { mode: "answer", question_token: @question.signed_id(purpose: :daily_question), input_text: "따뜻한 라테를 좋아해요." }
      end
      assert_response :success
      assert_select "turbo-frame#answer-helper .english-answer", text: "I like warm lattes."
      assert_select ".ipa-answer", text: "/aɪ laɪk wɔrm ˈlɑteɪz/"
      assert_select "textarea", text: "따뜻한 라테를 좋아해요."
    end
  end

  test "empty or oversized inputs and forged questions are rejected" do
    [ "", "가" * 301 ].each do |text|
      post language_help_path, params: { mode: "answer", question_token: @question.signed_id(purpose: :daily_question), input_text: text }
      assert_response :unprocessable_entity
      assert_select "[role=alert]"
    end
    post language_help_path, params: { mode: "question", question_token: "forged" }
    assert_response :unprocessable_entity
  end

  test "Gemini errors keep the input" do
    translator = Object.new
    translator.define_singleton_method(:call) { |**| raise GeminiText::Unavailable, "offline" }
    GeminiTranslation.stub(:new, -> { translator }) do
      post language_help_path, params: { mode: "answer", question_token: @question.signed_id(purpose: :daily_question), input_text: "라테를 좋아해요." }
      assert_response :service_unavailable
      assert_select "textarea", text: "라테를 좋아해요."
      assert_select "[role=alert]"
    end
  end

  test "example is generated from the signed question rather than arbitrary text" do
    translator = Object.new
    translator.define_singleton_method(:call) do |text:, mode:|
      raise "Wrong context" unless text == "What do you like to drink?" && mode == "example"
      { "translation" => "저는 따뜻한 차를 좋아해요." }
    end
    GeminiTranslation.stub(:new, -> { translator }) do
      post language_help_path, params: { mode: "example", question_token: @question.signed_id(purpose: :daily_question), input_text: "ignored" }
      assert_response :success
      assert_equal "저는 따뜻한 차를 좋아해요.", response.parsed_body.fetch("example")
    end
    post language_help_path, params: { mode: "example", question_token: "forged" }
    assert_response :unprocessable_entity
    assert response.parsed_body["error"].present?
  end

  test "visitors can request answer help before login" do
    sign_out
    translator = Object.new
    translator.define_singleton_method(:call) { |**| { "english" => "Hello.", "ipa" => "/həˈloʊ/" } }
    GeminiTranslation.stub(:new, -> { translator }) do
      post language_help_path, params: { mode: "answer", question_token: @question.signed_id(purpose: :daily_question), input_text: "안녕하세요" }
      assert_response :success
    end
  end
end
