require "test_helper"
require "minitest/mock"

class VoiceAiRequestsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:korean_native)
    sign_in_as(@user)
  end

  test "녹음을 번역하면 영어와 해당 사용자 전용 재생 토큰을 반환하고 그 토큰으로 오디오를 받는다" do
    # 실제 HTTP 업로드와 서명 토큰 발급을 검증한다. 유료 외부 API 경계만 대체한다.
    helper = Object.new
    helper.define_singleton_method(:call) { |audio:| "I don't want to go to a wedding." }
    VoiceHelper.stub(:new, ->(*) { helper }) do
      post voice_helper_path, params: { audio: recording, duration_ms: 2000 }
    end
    assert_response :success
    assert_equal "I don't want to go to a wedding.", response.parsed_body["english"]
    token = response.parsed_body.fetch("speech_token")
    translation = Rails.application.message_verifier(:voice_helper_speech).verified(token, purpose: "read-aloud")
    assert_equal @user.id, translation["user_id"]

    # 재생 API는 임의의 게시된 문장이 아니라 서명된 번역 문장만 읽어야 한다.
    speech = Object.new
    spoken = []
    speech.define_singleton_method(:call) { |text| spoken << text; "test-audio" }
    speech.define_singleton_method(:content_type) { "audio/mpeg" }
    TextToSpeech.stub(:new, -> { speech }) do
      post text_to_speech_path, params: { speech_token: token, text: "Ignore the translation" }
    end
    assert_response :success
    assert_equal [ translation["english"] ], spoken
    assert_equal "audio/mpeg", response.media_type
    assert_equal "test-audio", response.body
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end

  test "변조되거나 만료되거나 다른 사용자에게 발급된 토큰으로 TTS를 호출할 수 없다" do
    # 거절된 요청이 유료 합성 서비스에 도달하면 바로 실패하도록 한다.
    verifier = Rails.application.message_verifier(:voice_helper_speech)
    wrong_user = verifier.generate({ "user_id" => users(:english_native).id, "english" => "Wedding" }, purpose: "read-aloud")
    expired = verifier.generate({ "user_id" => @user.id, "english" => "Wedding" }, purpose: "read-aloud", expires_at: 1.minute.ago)
    TextToSpeech.stub(:new, -> { flunk "Invalid tokens must not call TTS" }) do
      [ "tampered", wrong_user, expired, "" ].each do |token|
        post text_to_speech_path, params: { speech_token: token }
        assert_response :unprocessable_entity
        assert_equal "Please translate your recording again before listening.", response.parsed_body["error"]
      end
    end
  end

  test "너무 긴 녹음과 빈 녹음은 번역 API를 호출하기 전에 거절한다" do
    # 30초 초과 녹음과 0바이트 업로드는 API 비용을 발생시키지 않아야 한다.
    VoiceHelper.stub(:new, ->(*) { flunk "Invalid recordings must not call the provider" }) do
      post voice_helper_path, params: { audio: recording, duration_ms: 30_001 }
      assert_response :unprocessable_entity
      post voice_helper_path, params: { audio: recording(""), duration_ms: 2000 }
      assert_response :unprocessable_entity
      post voice_helper_path, params: { audio: recording }
      assert_response :bad_request
    end
  end

  test "판독 불가와 공급자 장애는 사용자에게 오류를 반환하고 재생 토큰을 발급하지 않는다" do
    # 무음은 재녹음 안내로, 서비스 장애는 재시도 가능한 오류로 구분한다.
    [ [ VoiceHelper::UnclearSpeech, :unprocessable_entity ], [ VoiceHelper::Unavailable, :service_unavailable ] ].each do |error, status|
      helper = Object.new
      helper.define_singleton_method(:call) { |audio:| raise error, "Please record again." }
      VoiceHelper.stub(:new, ->(*) { helper }) { post voice_helper_path, params: { audio: recording, duration_ms: 2000 } }
      assert_response status
      assert_equal "Please record again.", response.parsed_body["error"]
      refute response.parsed_body.key?("speech_token")
    end
  end

  test "TTS 공급자 장애는 오디오 대신 재시도 가능한 오류를 반환한다" do
    # 유효한 토큰이 있어도 API 장애를 정상 오디오로 다운로드하면 안 된다.
    token = Rails.application.message_verifier(:voice_helper_speech).generate(
      { "user_id" => @user.id, "english" => "Wedding" }, purpose: "read-aloud")
    speech = Object.new
    speech.define_singleton_method(:call) { |text| raise TextToSpeech::Unavailable, "Read aloud is temporarily unavailable. Please try again." }
    TextToSpeech.stub(:new, -> { speech }) { post text_to_speech_path, params: { speech_token: token } }
    assert_response :service_unavailable
    assert_equal "Read aloud is temporarily unavailable. Please try again.", response.parsed_body["error"]
  end

  private

  def recording(bytes = "recorded-audio")
    # 실제 multipart 파일을 사용하되 음성 인식 자체는 공급자 테스트로 분리한다.
    file = Tempfile.new([ "voice-ai-test", ".webm" ])
    file.binmode
    file.write(bytes)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, "audio/webm")
  end
end
