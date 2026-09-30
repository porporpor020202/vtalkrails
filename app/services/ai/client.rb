require "net/http"
require "json"

module Ai
  class Client
    class Error < StandardError; end

    def self.configured?
      (ENV["OPENAI_API_KEY"].presence || Rails.application.credentials.dig(:openai, :api_key)).present?
    end

    def structured(instructions:, input:, schema:)
      body = request("responses", {
        model: ENV.fetch("OPENAI_TEXT_MODEL", "gpt-6-luna"),
        instructions: instructions,
        input: JSON.generate(input),
        store: false,
        max_output_tokens: 1800,
        text: { format: { type: "json_schema", name: "assistance", strict: true, schema: schema } }
      })
      raise Error, "Incomplete response" unless body["status"] == "completed"
      output = body.fetch("output", []).flat_map { |item| item.fetch("content", []) }
        .select { |part| part["type"] == "output_text" }.map { |part| part["text"] }.join
      JSON.parse(output)
    rescue JSON::ParserError, KeyError
      raise Error, "Invalid response"
    end

    def transcribe(file)
      response = request("audio/transcriptions", nil, form: [
        [ "model", ENV.fetch("OPENAI_TRANSCRIPTION_MODEL", "gpt-transcribe") ],
        [ "file", file ]
      ])
      response.fetch("text")
    rescue KeyError
      raise Error, "Invalid transcript"
    end

    def speech(text)
      request("audio/speech", {
        model: ENV.fetch("OPENAI_SPEECH_MODEL", "gpt-4o-mini-tts"),
        input: text,
        voice: "coral",
        instructions: "Speak clear, natural English at a slightly slower pace for a language learner.",
        response_format: "mp3"
      }, binary: true)
    end

    private

    def request(path, payload, form: nil, binary: false)
      key = ENV["OPENAI_API_KEY"].presence || Rails.application.credentials.dig(:openai, :api_key)
      raise Error, "AI is not configured" if key.blank?
      uri = URI("https://api.openai.com/v1/#{path}")
      req = Net::HTTP::Post.new(uri)
      req["Authorization"] = "Bearer #{key}"
      if form
        req.set_form(form, "multipart/form-data")
      else
        req["Content-Type"] = "application/json"
        req.body = JSON.generate(payload)
      end
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 90, write_timeout: 30) do |http|
        http.max_retries = 0
        http.request(req)
      end
      raise Error, "AI service unavailable" unless response.is_a?(Net::HTTPSuccess)
      binary ? response.body : JSON.parse(response.body)
    rescue JSON::ParserError, IOError, SystemCallError, Timeout::Error, SocketError, OpenSSL::SSL::SSLError
      raise Error, "AI service unavailable"
    end
  end
end
