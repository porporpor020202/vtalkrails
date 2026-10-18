require "net/http"
require "json"

class GeminiText
  class Unavailable < StandardError; end

  def call(prompt:, json: false)
    key = ENV["GEMINI_API_KEY"].presence || Rails.application.credentials.dig(:gemini, :api_key)
    raise Unavailable, "GEMINI_API_KEY is missing" if key.blank?
    model = ENV.fetch("GEMINI_QUESTION_MODEL", "gemini-3.8-flash")
    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["x-goog-api-key"] = key
    generation = { maxOutputTokens: 2048, thinkingConfig: { thinkingLevel: "low" } }
    generation[:responseMimeType] = "application/json" if json
    request.body = { contents: [ { parts: [ { text: prompt } ] } ], generationConfig: generation }.to_json
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 25) { |http| http.request(request) }
    raise Unavailable, "Gemini returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    parts = JSON.parse(response.body).dig("candidates", 0, "content", "parts") || []
    text = parts.reject { |part| part["thought"] }.filter_map { |part| part["text"] }.join.strip
    raise Unavailable, "Gemini returned empty text" if text.blank?
    text
  rescue JSON::ParserError, Timeout::Error, SocketError, SystemCallError, IOError, EOFError, Net::HTTPBadResponse, OpenSSL::SSL::SSLError => error
    raise Unavailable, error.class.name
  end
end
