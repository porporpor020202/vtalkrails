require "test_helper"

class VoiceAiSettingsTest < ActionDispatch::IntegrationTest
  setup do
    # 일반 로그인 절차를 거쳐 실제 관리자 namespace를 요청한다.
    @admin = users(:korean_native)
    @admin.update!(email_address: "porporpor020202@gmail.com")
    sign_in_as(@admin)
  end

  test "관리자는 번역과 TTS 모델 키 프롬프트를 각각 저장하고 빈 키 입력은 기존 값을 유지한다" do
    # 번역 정책과 키는 다음 요청부터 사용할 수 있도록 DB에 저장되어야 한다.
    patch admin_voice_helper_setting_path, params: { voice_helper_setting: {
      model_key: "gemini-3.5-flash-lite", gemini_api_key: " translation-secret ",
      prompt: "Translate {{native_language}} into everyday English."
    } }
    assert_redirected_to admin_voice_helper_setting_path
    assert_equal "translation-secret", VoiceHelperSetting.current.gemini_api_key
    assert_equal "Translate {{native_language}} into everyday English.", VoiceHelperSetting.current.prompt

    # TTS 키는 번역 키와 별개이며, 같은 Google 공급자여도 모델별로 구분한다.
    patch admin_text_to_speech_setting_path, params: { text_to_speech_setting: {
      model_key: "wavenet", wavenet_api_key: " wave-secret ", neural2_api_key: "neural-secret"
    } }
    assert_redirected_to admin_text_to_speech_setting_path
    patch admin_text_to_speech_setting_path, params: { text_to_speech_setting: {
      model_key: "neural2", wavenet_api_key: "", neural2_api_key: ""
    } }
    assert_equal "neural2", TextToSpeechSetting.current.model_key
    assert_equal "wave-secret", TextToSpeechSetting.current.api_key("wavenet")
    assert_equal "neural-secret", TextToSpeechSetting.current.api_key
    patch admin_voice_helper_setting_path, params: { voice_helper_setting: { gemini_api_key: "" } }
    assert_equal "translation-secret", VoiceHelperSetting.current.gemini_api_key

    # 저장된 비밀값이 HTML 입력란이나 오류 화면에 다시 노출되면 안 된다.
    [ admin_voice_helper_setting_path, admin_text_to_speech_setting_path ].each do |path|
      get path
      assert_response :success
      refute_includes response.body, "translation-secret"
      refute_includes response.body, "wave-secret"
      refute_includes response.body, "neural-secret"
      assert_select "input[type=password]"
    end
  end

  test "두 설정 페이지는 비용이 낮은 모델부터 표시하고 TTS 상단에서 공식 요금표를 새 탭으로 연다" do
    # 하단 작은 링크가 아니라 상단 버튼을 검증하고, 링크 대상도 고정한다.
    get admin_text_to_speech_setting_path
    assert_select "header a[href='https://cloud.google.com/text-to-speech/pricing'][target='_blank']", text: "Google TTS Pricing"
    assert_select "tbody tr td:first-child p:first-child" do |names|
      expected = TextToSpeechSetting::MODELS.sort_by { |key, _| TextToSpeechSetting.current.monthly_cost_usd(key) }.map { |_, model| model[:name] }
      assert_equal expected, names.map { |node| node.text.strip }
    end
    get admin_voice_helper_setting_path
    assert_select "tbody tr td:first-child span.font-bold.text-slate-950" do |names|
      expected = VoiceHelperSetting::MODELS.sort_by { |key, _| VoiceHelperSetting.current.monthly_cost_usd(key) }.map { |_, model| model[:name] }
      assert_equal expected, names.map { |node| node.text.strip }
    end
  end

  test "일반 사용자와 앱 WebView에서는 AI 설정을 조회하거나 변경할 수 없다" do
    # URL 직접 접근과 PATCH 요청 모두 막혀야 한다. 관리자도 앱에서는 접근할 수 없다.
    sign_in_as(users(:english_native))
    [ admin_voice_helper_setting_path, admin_text_to_speech_setting_path ].each do |path|
      get path
      assert_response :forbidden
      patch path
      assert_response :forbidden
    end
    sign_in_as(@admin)
    [ admin_voice_helper_setting_path, admin_text_to_speech_setting_path ].each do |path|
      get path, headers: { "User-Agent" => "vtalk/ios/1.0" }
      assert_response :forbidden
      patch path, headers: { "User-Agent" => "vtalk/android/1.0" }
      assert_response :forbidden
    end
  end

  test "잘못된 번역 모델은 저장하지 않고 오류를 표시한다" do
    # 잘못된 입력이 DB의 기존 유효한 설정을 덮어쓰지 않는지 확인한다.
    original = VoiceHelperSetting.current.model_key
    patch admin_voice_helper_setting_path, params: { voice_helper_setting: { model_key: "invalid" } }
    assert_response :unprocessable_entity
    assert_equal original, VoiceHelperSetting.current.reload.model_key
    assert_select "[role=alert]"
  end

  test "잘못된 TTS 모델은 저장하지 않고 오류를 표시한다" do
    # 번역 설정과 독립된 오류 경로도 검증하여 첫 실패가 다른 오류를 가리지 않게 한다.
    original = TextToSpeechSetting.current.model_key
    patch admin_text_to_speech_setting_path, params: { text_to_speech_setting: { model_key: "invalid" } }
    assert_response :unprocessable_entity
    assert_equal original, TextToSpeechSetting.current.reload.model_key
    assert_select "[role=alert]"
  end

  test "빈 프롬프트는 저장하지 않고 기존 프롬프트를 유지한다" do
    # 모델을 바꾸지 않은 프롬프트 검증 오류는 정상적으로 다시 렌더링해야 한다.
    original = VoiceHelperSetting.current.prompt
    patch admin_voice_helper_setting_path, params: { voice_helper_setting: { prompt: "" } }
    assert_response :unprocessable_entity
    assert_equal original, VoiceHelperSetting.current.reload.prompt
    assert_select "[role=alert]"
  end
end
