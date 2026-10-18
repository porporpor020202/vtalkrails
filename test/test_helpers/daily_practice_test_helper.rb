module DailyPracticeTestHelper
  def question_for(date = Date.current)
    DailyQuestion.find_or_create_by!(asked_on: date) { |question| question.question = "What made you smile today?"; question.source = "sample" }
  end

  def audio_upload
    Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/practice.wav"), "audio/wav")
  end

  def complete_practice(user, date = Date.current)
    practice = user.daily_practices.build(daily_question: question_for(date), practiced_on: date, duration_ms: 2000, completed_at: date.in_time_zone + 12.hours)
    practice.audio.attach(io: File.open(Rails.root.join("test/fixtures/files/practice.wav")), filename: "practice.wav", content_type: "audio/wav")
    practice.save!
    practice
  end
end
