require "test_helper"
require "minitest/mock"

class GeminiQuestionTest < ActiveSupport::TestCase
  test "the day's question is generated once and remains stable" do
    calls = 0
    generator = Object.new
    generator.define_singleton_method(:call) { |date:| calls += 1; "What made you smile today?" }
    GeminiQuestion.stub(:new, -> { generator }) do
      first = DailyQuestion.for_date(Date.current)
      assert_equal "gemini", first.source
      assert_equal first, DailyQuestion.for_date(Date.current)
      assert_equal 1, calls
    end
  end

  test "unavailable Gemini uses an explicitly labeled sample" do
    generator = Object.new
    generator.define_singleton_method(:call) { |date:| raise GeminiQuestion::Unavailable, "offline" }
    GeminiQuestion.stub(:new, -> { generator }) do
      question = DailyQuestion.for_date(Date.current)
      assert_equal "sample", question.source
      assert question.question.end_with?("?")
    end
  end

  test "Gemini API request authenticates server side and parses only question text" do
    previous = ENV["GEMINI_API_KEY"]
    ENV["GEMINI_API_KEY"] = "test-secret"
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.define_singleton_method(:body) { { candidates: [ { content: { parts: [ { text: "What made you smile today?" } ] } } ] }.to_json }
    http = Object.new
    http.define_singleton_method(:request) do |request|
      raise "API key missing" unless request["x-goog-api-key"] == "test-secret"
      raise "User data leaked" if request.body.include?("english@example.com")
      response
    end
    Net::HTTP.stub(:start, ->(*args, **options, &block) { block.call(http) }) do
      assert_equal "What made you smile today?", GeminiQuestion.new.call(date: Date.current)
    end
  ensure
    previous ? ENV["GEMINI_API_KEY"] = previous : ENV.delete("GEMINI_API_KEY")
  end
end
