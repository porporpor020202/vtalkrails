require "test_helper"
require "minitest/mock"
require_relative "../test_helpers/daily_practice_test_helper"

class NativeLanguagesTest < ActionDispatch::IntegrationTest
  include DailyPracticeTestHelper

  setup { question_for }

  test "first visit asks for language before generating a question and remembers guest choice" do
    DailyQuestion.stub(:for_date, ->(*) { flunk "Do not generate a question before language selection" }) do
      get root_path
      assert_response :success
      assert_select "input[type=radio]", count: NativeLanguage::OPTIONS.size
      assert_select "#daily-question", count: 0
      assert_equal %w[es ja ko zh zh-TW], css_select('input[type="radio"]').map { |input| input["value"] }
      assert_select 'input[type="radio"][value="en"]', count: 0
    end
    patch native_language_path, params: { native_language: "ja" }
    assert_redirected_to root_path
    follow_redirect!
    assert_select "html[lang=ja]"
    assert_select "label", text: "言いたいことを日本語で書いてください。まず英語の表現を確認して、声に出してみましょう！"
    assert_select "#daily-question", text: question_for.question
    get settings_path
    assert_select "h1", text: "設定"
    get root_path
    assert_select ".language-page", count: 0
  end

  test "each supported language has complete UI and public pages" do
    expected_keys = I18n.t("ui", locale: :ko).keys.sort
    NativeLanguage::OPTIONS.each_key do |language|
      assert_equal expected_keys, I18n.t("ui", locale: language).keys.sort
      patch native_language_path, params: { native_language: language }
      follow_redirect!
      assert_select "html[lang=?]", language
      assert_select "input[type=submit][value=?]", I18n.t("ui.translate_answer", locale: language)
      [ privacy_path, support_path, delete_account_path, new_session_path ].each do |path|
        get path
        assert_response :success
        assert_select "html[lang=?]", language
        assert_not_includes response.body, "Translation missing"
      end
    end
    # A fresh visitor must not inherit the preceding request's locale.
    cookies.delete("native_language")
    get root_path
    assert_select "html[lang=ko]"
    assert_select ".language-page"
  end

  test "choice is validated and is saved to account on authentication and can be changed" do
    patch native_language_path, params: { native_language: "../invalid" }
    assert_response :unprocessable_entity
    assert_nil cookies[:native_language]
    user = users(:spanish_native)
    user.update!(native_language: nil)
    patch native_language_path, params: { native_language: "es" }
    get authenticate_by_token_google_oauth_sessions_path(token: user.signed_id(purpose: :native_auth))
    assert_equal "es", user.reload.native_language
    cookies.delete("native_language")
    get root_path
    assert_select "html[lang=es]"
    patch native_language_path, params: { native_language: "zh" }
    assert_equal "zh", user.reload.native_language
    follow_redirect!
    assert_select "html[lang=zh]"
  end

  test "Gemini prompts use the selected language for examples translation and English answers" do
    prompts = []
    client = Object.new
    client.define_singleton_method(:call) do |prompt:, **|
      prompts << prompt
      prompt.include?('"english"') ? { english: "I like tea.", ipa: "/aɪ laɪk ti/" }.to_json : { translation: "お茶が好きです。" }.to_json
    end
    GeminiText.stub(:new, -> { client }) do
      I18n.with_locale(:ja) do
        %w[question example answer].each { |mode| GeminiTranslation.new.call(text: "お茶が好きです。", mode: mode) }
      end
    end
    assert_equal 3, prompts.size
    assert prompts.all? { |prompt| prompt.include?("Japanese") }
    assert_includes prompts.last, "simple spoken English"
  end

  test "completion and recording labels use account language on every device" do
    user = users(:japanese_native)
    complete_practice(user)
    sign_in_as(user)
    NativeLanguage::OPTIONS.each_key do |language|
      patch native_language_path, params: { native_language: language }
      cookies.delete("native_language")
      get root_path
      assert_select "h1", text: I18n.t("ui.praise", locale: language)
      assert_select ".completion-count", text: I18n.t("ui.streak", locale: language, count: 1)
      assert_select ".next-practice-heading", text: /#{Regexp.escape(I18n.t("ui.reset_time", locale: language))}/
    end
  end

  test "traditional Chinese uses a separate UI and Gemini writing system" do
    patch native_language_path, params: { native_language: "zh-TW" }
    follow_redirect!
    assert_select "html[lang=zh-TW]"
    assert_select "label", text: "用繁體中文寫下你想說的話。先看看英語怎麼說，再大膽說出來！"
    get settings_path
    assert_select "h1", text: "設定"
    patch native_language_path, params: { native_language: "en" }
    assert_response :unprocessable_entity
    assert_equal "zh-TW", cookies["native_language"]

    prompts = []
    client = Object.new
    client.define_singleton_method(:call) do |prompt:, **|
      prompts << prompt
      { translation: "茶" }.to_json
    end
    GeminiText.stub(:new, -> { client }) do
      %w[zh zh-TW].each do |language|
        I18n.with_locale(language) { GeminiTranslation.new.call(text: "What do you drink?", mode: "question") }
      end
    end
    assert_includes prompts.first, "Simplified Chinese"
    assert_includes prompts.last, "Traditional Chinese"
  end

  test "question translations use each selected native language with separate caches" do
    translations = {
      "ko" => "무엇이 당신을 웃게 했나요?",
      "zh" => "什么让你笑了？",
      "zh-TW" => "什麼讓你笑了？",
      "ja" => "何があなたを笑顔にしましたか？",
      "es" => "¿Qué te hizo sonreír?"
    }
    requested_locales = []
    translator = Object.new
    translator.define_singleton_method(:call) do |text:, mode:|
      raise "Wrong translation context" unless text == "What made you smile today?" && mode == "question"
      requested_locales << I18n.locale.to_s
      { "translation" => translations.fetch(I18n.locale.to_s) }
    end
    Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
      GeminiTranslation.stub(:new, -> { translator }) do
        (NativeLanguage::OPTIONS.keys + [ "zh-TW", "ko" ]).each do |language|
          user = User.find_or_create_by!(oauth_provider: "google", oauth_uid: "locale-quota-#{language}") do |record|
            record.email_address = "locale-#{language}@example.invalid"
          end
          sign_in_as(user)
          patch native_language_path, params: { native_language: language }
          post language_help_path, params: { mode: "question", question_token: question_for.signed_id(purpose: :daily_question) }
          assert_response :success
          assert_select ".question-translation p[lang=?]", language, text: translations.fetch(language)
        end
      end
    end
    assert_equal NativeLanguage::OPTIONS.keys.sort, requested_locales.uniq.sort
  end
end
