class GeminiQuestion
  Unavailable = GeminiText::Unavailable

  def call(date:)
    previous = DailyQuestion.order(asked_on: :desc).limit(14).pluck(:question)
    text = GeminiText.new.call(prompt: "Create ONE friendly beginner English speaking-practice question for #{date.iso8601}. Answerable in one short sentence about everyday life. Maximum 16 words. Avoid sensitive personal information and adult topics. Do not repeat these recent questions: #{previous.to_json}. Return only the question in English, ending in a question mark; no quotes, greeting, instructions, translation or commentary.")
    raise Unavailable, "Gemini returned an invalid question" unless text.length <= 240 && text.count("?") == 1 && text.end_with?("?")
    text
  end
end
