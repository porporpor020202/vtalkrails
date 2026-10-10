require "test_helper"
require "minitest/mock"

class VoiceAiProvidersTest < ActiveSupport::TestCase
  setup do
    # 네트워크 경계만 가짜 응답으로 바꾼다. 요청 구성과 응답 파싱은 실제 코드를 실행한다.
    @user = users(:korean_native)
    VoiceHelperSetting.current.update!(model_key: "gemini-3.5-flash-lite", gemini_api_key: "translation-key",
      prompt: "Translate {{native_language}} ({{native_language_code}}).")
    @file = Tempfile.new([ "voice-helper-test", ".m4a" ])
    @file.write("recorded-audio")
    @file.rewind
    @audio = ActionDispatch::Http::UploadedFile.new(tempfile: @file, filename: "recording.m4a", type: "audio/mp4")
  end

  teardown { @file.close! }

  test "Gemini는 저장된 모델 키 프롬프트 모국어와 녹음을 사용하고 영어 표현만 반환한다" do
    # 질문/문장/단어 형태의 모델 응답을 모두 처리한다. 가짜 응답은 번역 품질 증명이 아니다.
    [ "I don't want to go to a wedding.", "Wedding" ].each do |english|
      @file.rewind
      with_http_response(gemini_response(english)) do |uri, request|
        assert_equal english, VoiceHelper.new(@user).call(audio: @audio)
        assert_equal "generativelanguage.googleapis.com", uri.host
        assert_includes request.path, "gemini-3.5-flash-lite:generateContent"
        assert_equal "translation-key", request["x-goog-api-key"]
        body = JSON.parse(request.body)
        assert_includes body.dig("systemInstruction", "parts", 0, "text"), "Translate Korean (ko)."
        assert_equal "audio/m4a", body.dig("contents", 0, "parts", 0, "inlineData", "mimeType")
        assert_equal "recorded-audio", Base64.decode64(body.dig("contents", 0, "parts", 0, "inlineData", "data"))
      end
    end
  end

  test "관리자가 프롬프트를 바꾸면 다음 번역 요청부터 새 정책을 사용한다" do
    # 서비스 클래스의 초기값이 아니라 DB에 저장된 최신 프롬프트가 실제 전송되어야 한다.
    VoiceHelperSetting.current.update!(prompt: "New policy for {{native_language}}.")
    with_http_response(gemini_response("Wedding")) do |_, request|
      assert_equal "Wedding", VoiceHelper.new(@user).call(audio: @audio)
      assert_includes JSON.parse(request.body).dig("systemInstruction", "parts", 0, "text"), "New policy for Korean."
    end
  end

  test "OpenAI와 Groq 모델은 먼저 음성을 받아쓴 뒤 그 내용만 영어로 변환한다" do
    # 두 요청의 순서와 공급자별 인증 키를 확인한다. 실제 음성/LLM 호출은 하지 않는다.
    %w[openai-mini openai-transcribe groq-turbo].each do |model|
      @file.rewind
      VoiceHelperSetting.current.update!(model_key: model, openai_api_key: "openai-secret", groq_api_key: "groq-secret")
      requests = []
      hosts = []
      responses = [ { text: "결혼식 가기 싫어." }, { status: "completed", output: [ { type: "message", content: [ { type: "output_text", text: { english: "I don't want to go to a wedding." }.to_json } ] } ] } ]
      http = Object.new
      http.define_singleton_method(:request) do |request|
        requests << request
        response = Net::HTTPOK.new("1.1", "200", "OK")
        body = responses.shift.to_json
        response.define_singleton_method(:body) { body }
        response
      end
      transport = lambda { |host, port, **options, &block| hosts << host; block.call(http) }
      Net::HTTP.stub(:start, transport) do
        assert_equal "I don't want to go to a wedding.", VoiceHelper.new(@user).call(audio: @audio)
      end
      assert_equal 2, requests.size
      assert_equal "/openai/v1/audio/transcriptions", requests.first.path if model == "groq-turbo"
      assert_equal model == "groq-turbo" ? "api.groq.com" : "api.openai.com", hosts.first
      assert_equal model == "groq-turbo" ? "Bearer groq-secret" : "Bearer openai-secret", requests.first["Authorization"]
      assert_equal "Bearer openai-secret", requests.last["Authorization"]
      assert_equal "/v1/responses", requests.last.path
      assert_equal "결혼식 가기 싫어.", JSON.parse(requests.last.body)["input"]
      assert_includes JSON.parse(requests.last.body)["instructions"], "Korean (ko)"
    end
  end

  test "무음 잘못된 JSON 여러 줄 결과와 중단된 응답을 정상 번역으로 표시하지 않는다" do
    # 공급자 결과가 계약을 어기면 오염된 결과나 추측 문장을 사용자에게 보여주지 않는다.
    [ [ "", VoiceHelper::UnclearSpeech ], [ "one\ntwo", VoiceHelper::Unavailable ] ].each do |english, error|
      @file.rewind
      with_http_response(gemini_response(english)) { assert_raises(error) { VoiceHelper.new(@user).call(audio: @audio) } }
    end
    @file.rewind
    data = gemini_response("Wedding")
    data["candidates"][0]["finishReason"] = "MAX_TOKENS"
    with_http_response(data) { assert_raises(VoiceHelper::Unavailable) { VoiceHelper.new(@user).call(audio: @audio) } }
    # JSON이 아닌 출력이나 english 필드가 없는 응답도 같은 오류로 처리한다.
    [ "not-json", { wrong: "Wedding" }.to_json ].each do |invalid|
      @file.rewind
      data = gemini_response("Wedding")
      data["candidates"][0]["content"]["parts"][0]["text"] = invalid
      with_http_response(data) { assert_raises(VoiceHelper::Unavailable) { VoiceHelper.new(@user).call(audio: @audio) } }
    end
  end

  test "모국어 누락과 지원하지 않는 음성 형식은 외부 요청 전에 거절한다" do
    # 잘못된 입력이 공급자 비용으로 이어지지 않도록 사전 검증을 확인한다.
    Net::HTTP.stub(:start, ->(*) { flunk "Invalid input must not call the provider" }) do
      @user.native_language = nil
      assert_raises(VoiceHelper::UnclearSpeech) { VoiceHelper.new(@user).call(audio: @audio) }
      @user.native_language = languages(:korean)
      @audio.content_type = "text/plain"
      assert_raises(VoiceHelper::UnclearSpeech) { VoiceHelper.new(@user).call(audio: @audio) }
    end
  end

  test "Google와 OpenAI TTS는 선택된 모델의 전용 키로 영어를 합성한다" do
    # 번역 키와 다른 모델의 키를 섞지 않고, 모델 변경 시 음성 및 API를 바꿔야 한다.
    { "wavenet" => "en-US-Wavenet-F", "neural2" => "en-US-Neural2-F", "chirp3" => "en-US-Chirp3-HD-Aoede", "tts1" => "tts-1", "tts1hd" => "tts-1-hd" }.each do |key, voice|
      setting = TextToSpeechSetting.current
      setting.update!(model_key: key, "#{key}_api_key" => "#{key}-secret")
      google = %w[wavenet neural2 chirp3].include?(key)
      body = google ? { audioContent: Base64.strict_encode64("mp3-audio") } : "mp3-audio"
      with_http_response(body) do |uri, request|
        speech = TextToSpeech.new
        assert_equal "mp3-audio", speech.call("Wedding")
        assert_equal "audio/mpeg", speech.content_type
        payload = JSON.parse(request.body)
        if google
          assert_equal "texttospeech.googleapis.com", uri.host
          assert_equal "#{key}-secret", request["x-goog-api-key"]
          assert_equal voice, payload.dig("voice", "name")
          assert_equal "Wedding", payload.dig("input", "text")
        else
          assert_equal "api.openai.com", uri.host
          assert_equal "Bearer #{key}-secret", request["Authorization"]
          assert_equal voice, payload["model"]
          assert_equal "Wedding", payload["input"]
        end
      end
    end
  end

  test "Gemini TTS 두 모델은 각자의 키를 사용하고 WAV 오디오를 반환한다" do
    # 헤더 없는 PCM을 WAV로 잘못 재생하지 않도록 WAV 파일 형식 검증도 수행한다.
    wav = "RIFF" + [ 36 ].pack("V") + "WAVE" + "test-audio"
    %w[gemini_lite gemini_flash].each do |key|
      TextToSpeechSetting.current.update!(model_key: key, "#{key}_api_key" => "#{key}-secret")
      with_http_response({ steps: [ { type: "model_output", content: [ { type: "audio", data: Base64.strict_encode64(wav) } ] } ] }) do |_, request|
        speech = TextToSpeech.new
        assert_equal wav, speech.call("Wedding")
        assert_equal "audio/wav", speech.content_type
        assert_equal "#{key}-secret", request["x-goog-api-key"]
        assert_equal TextToSpeechSetting::MODELS.fetch(key)[:model], JSON.parse(request.body)["model"]
      end
    end
    with_http_response({ steps: [ { type: "model_output", content: [ { type: "audio", data: Base64.strict_encode64("raw-pcm") } ] } ] }) do
      assert_raises(TextToSpeech::Unavailable) { TextToSpeech.new.call("Wedding") }
    end
  end

  test "TTS 키 누락과 공급자 오류는 다른 키로 우회하지 않고 실패를 알린다" do
    # 번역 Gemini 키가 설정되어 있어도 TTS 키로 재사용하면 안 된다.
    TextToSpeechSetting.current.update!(model_key: "gemini_lite", gemini_lite_api_key: nil)
    Net::HTTP.stub(:start, ->(*) { flunk "Missing TTS key must not call the provider" }) do
      assert_raises(TextToSpeech::Unavailable) { TextToSpeech.new.call("Wedding") }
    end
    TextToSpeechSetting.current.update!(model_key: "wavenet", wavenet_api_key: "tts-key")
    with_http_response({ error: "private provider detail" }, status: 503) do
      error = assert_raises(TextToSpeech::Unavailable) { TextToSpeech.new.call("Wedding") }
      refute_includes error.message, "private provider detail"
    end
  end

  private

  def gemini_response(english)
    { "candidates" => [ { "finishReason" => "STOP", "content" => { "parts" => [ { "text" => { english: english }.to_json } ] } } ] }
  end

  def with_http_response(body, status: 200)
    response = (status == 200 ? Net::HTTPOK : Net::HTTPServiceUnavailable).new("1.1", status.to_s, "test")
    response.define_singleton_method(:body) { body.is_a?(String) ? body : JSON.generate(body) }
    request_seen = nil
    uri_seen = nil
    http = Object.new
    http.define_singleton_method(:request) { |request| request_seen = request; response }
    transport = lambda do |host, port, **options, &block|
      uri_seen = URI("https://#{host}")
      block.call(http)
    end
    # 요청을 먼저 실행하고 블록 안에서 캡처된 요청을 검사할 수 있도록 지연 프록시를 사용한다.
    proxy = Object.new
    proxy.define_singleton_method(:method_missing) { |name, *args| request_seen.public_send(name, *args) }
    host_proxy = Object.new
    host_proxy.define_singleton_method(:host) { uri_seen.host }
    Net::HTTP.stub(:start, transport) { yield host_proxy, proxy }
  end
end
