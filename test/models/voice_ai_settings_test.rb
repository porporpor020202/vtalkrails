require "test_helper"

class VoiceAiSettingsModelTest < ActiveSupport::TestCase
  test "번역과 TTS 비용은 월 사용 횟수와 원화 환율을 반영한다" do
    # 사용자가 요청한 2,000명 × 하루 5회 × 30일 = 월 300,000회를 직접 계산한다.
    translation = VoiceHelperSetting.current
    translation.update!(estimated_users: 2000, daily_uses: 5, audio_seconds: 10, usd_to_krw: 1400)
    assert_equal 300_000, translation.monthly_requests
    assert_in_delta 78.3, translation.monthly_cost_usd("gemini-3.5-flash-lite"), 0.001
    assert_in_delta 109_620, translation.monthly_cost_krw("gemini-3.5-flash-lite"), 0.01

    speech = TextToSpeechSetting.current
    speech.update!(estimated_users: 2000, daily_uses: 5, text_characters: 50, audio_seconds: 3, usd_to_krw: 1400)
    assert_equal 300_000, speech.monthly_requests
    assert_in_delta 60, speech.monthly_cost_usd("wavenet"), 0.001
    assert_in_delta 84_000, speech.monthly_cost_krw("wavenet"), 0.01
    travel_to Time.zone.local(2026, 10, 10) do
      assert_in_delta 141.375, speech.monthly_cost_usd("gemini_lite"), 0.001
    end
  end

  test "번역과 TTS API 키는 DB 원문에 평문으로 저장되지 않는다" do
    # 화면에서 숨기는 것과 별개로 DB 저장값 자체가 암호화되어 있어야 한다.
    translation = VoiceHelperSetting.current
    translation.update!(gemini_api_key: "translation-secret")
    speech = TextToSpeechSetting.current
    speech.update!(wavenet_api_key: "tts-secret")
    refute_includes translation.gemini_api_key_before_type_cast, "translation-secret"
    refute_includes speech.wavenet_api_key_before_type_cast, "tts-secret"
    assert_equal "translation-secret", translation.reload.gemini_api_key
    assert_equal "tts-secret", speech.reload.api_key("wavenet")
  end
end
