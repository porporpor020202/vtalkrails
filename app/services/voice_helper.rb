require "net/http"
require "base64"

class VoiceHelper
  class Unavailable < StandardError; end
  class UnclearSpeech < StandardError; end

  RESULT_SCHEMA = {
    type: "object", properties: { english: { type: "string" } },
    required: [ "english" ], additionalProperties: false
  }.freeze

  def initialize(user)
    @language = user.native_language
    @setting = VoiceHelperSetting.current
    @model = VoiceHelperSetting::MODELS.fetch(@setting.model_key)
  end

  def call(audio:)
    raise UnclearSpeech, "Choose your native language in Settings first." unless @language
    unless VoiceHelperSetting.missing_keys(@setting.model_key).empty?
      raise Unavailable, "Voice helper is not connected yet. Please try again later."
    end

    @audio = audio
    @mime_type = audio.content_type.to_s.split(";").first
    unless %w[audio/webm audio/mp4 audio/m4a audio/ogg audio/wav audio/mpeg audio/mp3].include?(@mime_type)
      raise UnclearSpeech, "This audio format is not supported. Please record again."
    end

    result = @model[:provider] == :gemini ? generate_with_gemini : generate_with_openai(transcribe)
    english = JSON.parse(result).fetch("english")
    raise Unavailable, "Voice helper returned an incomplete response. Please try again." unless english.is_a?(String)
    english = english.strip
    if english.blank?
      raise UnclearSpeech, "We could not understand your voice. Please record again."
    end
    if english.length > 1000 || english.match?(/[\r\n]/)
      raise Unavailable, "Voice helper could not create an English phrase. Please try again."
    end
    english
  rescue JSON::ParserError, KeyError, NoMethodError
    raise Unavailable, "Voice helper returned an incomplete response. Please try again."
  end

  private

  def instructions
    prompt = @setting.prompt
      .gsub("{{native_language}}", @language.label)
      .gsub("{{native_language_code}}", @language.code)
    # Keep the response contract independent of the editable translation policy.
    "#{prompt}\nReturn JSON with exactly one string field named english. Put the translation on one line."
  end

  def generate_with_gemini
    mime_type = @mime_type.in?(%w[audio/mp4 audio/m4a]) ? "audio/m4a" : @mime_type
    thinking = @setting.model_key == "gemini-2.5-flash-lite" ? { thinkingBudget: 0 } : { thinkingLevel: "MINIMAL" }
    payload = {
      systemInstruction: { parts: [ { text: instructions } ] },
      contents: [ { role: "user", parts: [ { inlineData: { mimeType: mime_type, data: Base64.strict_encode64(@audio.tempfile.read) } } ] } ],
      generationConfig: {
        responseMimeType: "application/json", responseJsonSchema: RESULT_SCHEMA,
        maxOutputTokens: 1024, thinkingConfig: thinking
      }
    }
    data = json_request("https://generativelanguage.googleapis.com/v1beta/models/#{@setting.model_key}:generateContent", payload,
      "x-goog-api-key" => VoiceHelperSetting.api_key(:gemini))
    candidate = data.fetch("candidates").first
    raise Unavailable, "Voice helper could not create an English phrase. Please try again." unless candidate["finishReason"] == "STOP"
    candidate.fetch("content").fetch("parts").reject { |part| part["thought"] }.filter_map { |part| part["text"] }.join
  end

  def transcribe
    groq = @model[:provider] == :groq
    provider = groq ? :groq : :openai
    url = groq ? "https://api.groq.com/openai/v1/audio/transcriptions" : "https://api.openai.com/v1/audio/transcriptions"
    uri = URI(url)
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{VoiceHelperSetting.api_key(provider)}"
    language_field = @model[:transcription_model] == "gpt-transcribe" ? "languages[]" : "language"
    @audio.tempfile.rewind
    request.set_form([
      [ "model", @model[:transcription_model] ],
      [ language_field, @language.code ],
      [ "file", @audio.tempfile, { filename: "voice.#{audio_extension}", content_type: @mime_type } ]
    ], "multipart/form-data")
    text = perform(uri, request).fetch("text").to_s.strip
    raise UnclearSpeech, "We could not understand your voice. Please record again." if text.blank?
    text
  end

  def generate_with_openai(transcript)
    data = json_request("https://api.openai.com/v1/responses", {
      model: "gpt-6-luna", instructions: instructions, input: transcript,
      reasoning: { effort: "none" }, max_output_tokens: 512, store: false,
      text: { format: { type: "json_schema", name: "english_expression", strict: true, schema: RESULT_SCHEMA } }
    }, "Authorization" => "Bearer #{VoiceHelperSetting.api_key(:openai)}")
    raise Unavailable, "Voice helper could not create an English phrase. Please try again." unless data["status"] == "completed"
    data.fetch("output").select { |item| item["type"] == "message" }
      .flat_map { |item| item.fetch("content") }
      .select { |part| part["type"] == "output_text" }.map { |part| part.fetch("text") }.join
  end

  def audio_extension
    case @mime_type
    when "audio/mp4", "audio/m4a" then "m4a"
    when "audio/ogg" then "ogg"
    when "audio/wav" then "wav"
    when "audio/mpeg", "audio/mp3" then "mp3"
    else "webm"
    end
  end

  def json_request(url, payload, headers)
    uri = URI(url)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    headers.each { |key, value| request[key] = value }
    request.body = JSON.generate(payload)
    perform(uri, request)
  end

  def perform(uri, request)
    # Never log audio, transcripts, provider response bodies or API keys.
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 40, write_timeout: 10) do |http|
      http.request(request)
    end
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.warn("Voice helper provider=#{uri.host} status=#{response.code}")
      raise Unavailable, "Voice helper is temporarily unavailable. Please try again."
    end
    JSON.parse(response.body)
  rescue Timeout::Error, IOError, SystemCallError, SocketError, OpenSSL::SSL::SSLError
    raise Unavailable, "Voice helper could not connect. Please try again."
  end
end
