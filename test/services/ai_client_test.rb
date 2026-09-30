require "test_helper"
require "minitest/mock"

class AiClientTest < ActiveSupport::TestCase
  def response(body, status = "200")
    klass = status == "200" ? Net::HTTPOK : Net::HTTPUnauthorized
    value = klass.new("1.1", status, "test")
    value.instance_variable_set(:@read, true)
    value.body = body
    value
  end

  def with_response(response)
    captured = nil
    http = Object.new
    http.define_singleton_method(:max_retries=) { |_value| }
    http.define_singleton_method(:request) { |request| captured = request; response }
    previous_key = ENV["OPENAI_API_KEY"]
    ENV["OPENAI_API_KEY"] = "test-key"
    Net::HTTP.stub(:start, ->(*_args, **_options, &block) { block.call(http) }) do
      yield Ai::Client.new, -> { captured }
    end
  ensure
    ENV["OPENAI_API_KEY"] = previous_key
  end

  test "Responses request uses strict schema and disables response storage" do
    body = { status: "completed", output: [
      { type: "reasoning" },
      { type: "message", content: [ { type: "output_text", text: '{"meaning":"안녕"}' } ] }
    ] }.to_json
    with_response(response(body)) do |client, captured|
      result = client.structured(instructions: "Translate", input: { draft: "Hello" },
        schema: { type: "object" })
      assert_equal({ "meaning" => "안녕" }, result)
      payload = JSON.parse(captured.call.body)
      assert_equal false, payload["store"]
      assert_equal true, payload.dig("text", "format", "strict")
      assert_equal({ "draft" => "Hello" }, JSON.parse(payload["input"]))
    end
  end

  test "refusals and incomplete responses are not parsed as successful results" do
    [ { status: "incomplete", output: [] },
      { status: "completed", output: [ { content: [ { type: "refusal", refusal: "No" } ] } ] }
    ].each do |body|
      with_response(response(body.to_json)) do |client, _|
        assert_raises(Ai::Client::Error) do
          client.structured(instructions: "Translate", input: {}, schema: {})
        end
      end
    end
  end

  test "provider failure does not disclose provider response" do
    with_response(response('{"error":"private details"}', "401")) do |client, _|
      error = assert_raises(Ai::Client::Error) { client.speech("Hello") }
      refute_includes error.message, "private"
    end
  end

  test "speech returns binary audio without JSON parsing" do
    with_response(response("ID3-test-audio")) do |client, captured|
      assert_equal "ID3-test-audio", client.speech("Hello")
      assert_equal "mp3", JSON.parse(captured.call.body)["response_format"]
    end
  end

  test "transcription posts the audio as multipart data" do
    with_response(response('{"text":"Hello"}')) do |client, captured|
      File.open(file_fixture("sample.webm")) do |file|
        assert_equal "Hello", client.transcribe(file)
      end
      assert_equal "multipart/form-data", captured.call.content_type
      assert_equal "/v1/audio/transcriptions", captured.call.path
    end
  end
end
