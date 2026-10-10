require "net/http"
require "base64"

class TextToSpeech
  class Unavailable < StandardError; end
  attr_reader :content_type

  def call(text)
    setting = TextToSpeechSetting.current
    key = setting.api_key
    raise Unavailable, "Read aloud is not connected yet. Please try again later." unless key
    model = TextToSpeechSetting::MODELS.fetch(setting.model_key)
    @content_type = "audio/mpeg"
    return generate_with_gemini(text, model, key) if model[:provider] == :gemini
    google = model[:provider] == :google
    uri = URI(google ? "https://texttospeech.googleapis.com/v1/text:synthesize" : "https://api.openai.com/v1/audio/speech")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    if google
      request["x-goog-api-key"] = key
      request.body = JSON.generate(input: { text: text }, voice: { languageCode: "en-US", name: model[:voice] }, audioConfig: { audioEncoding: "MP3" })
    else
      request["Authorization"] = "Bearer #{key}"
      request.body = JSON.generate(model: model[:model], voice: model[:voice], input: text, response_format: "mp3")
    end
    response = perform(uri, request)
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.warn("Text to speech provider=#{uri.host} status=#{response.code}")
      raise Unavailable, "Read aloud is temporarily unavailable. Please try again."
    end
    audio = google ? Base64.strict_decode64(JSON.parse(response.body).fetch("audioContent")) : response.body
    raise Unavailable, "The voice could not be generated. Please try again." if audio.blank?
    audio
  rescue JSON::ParserError, KeyError, ArgumentError, Timeout::Error, IOError, SystemCallError, SocketError, OpenSSL::SSL::SSLError
    raise Unavailable, "The voice could not be generated. Please try again."
  end

  private

  def generate_with_gemini(text, model, key)
    uri = URI("https://generativelanguage.googleapis.com/v1beta/interactions")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["x-goog-api-key"] = key
    request.body = JSON.generate(
      model: model[:model], store: false,
      input: [ { type: "user_input", content: [ { type: "text", text: text,
        annotations: [ { type: "speech_metadata", style: "Natural everyday American English, clear pronunciation, normal pace." } ] } ] } ],
      response_format: { type: "audio", mime_type: "audio/wav" },
      generation_config: { speech_config: [ { voice: model[:voice] } ] }
    )
    response = perform(uri, request)
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.warn("Text to speech provider=#{uri.host} status=#{response.code}")
      raise Unavailable, "Read aloud is temporarily unavailable. Please try again."
    end
    data = JSON.parse(response.body)
    block = data.fetch("steps").select { |step| step["type"] == "model_output" }
      .flat_map { |step| step.fetch("content") }.reverse.find { |part| part["type"] == "audio" }
    raise Unavailable, "The voice could not be generated. Please try again." unless block
    audio = Base64.strict_decode64(block.fetch("data"))
    # Request WAV explicitly so headerless PCM cannot be mistaken for playable audio.
    unless audio.start_with?("RIFF") && audio.byteslice(8, 4) == "WAVE"
      raise Unavailable, "The voice could not be generated. Please try again."
    end
    @content_type = "audio/wav"
    audio
  end

  def perform(uri, request)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 40, write_timeout: 10) { |http| http.request(request) }
  end
end
