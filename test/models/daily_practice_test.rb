require "test_helper"
require_relative "../test_helpers/daily_practice_test_helper"

class DailyPracticeModelTest < ActiveSupport::TestCase
  include DailyPracticeTestHelper
  include ActiveJob::TestHelper

  setup { @user = users(:english_native) }

  test "streak counts consecutive dates and survives until the end of the next day" do
    travel_to Time.zone.local(2026, 10, 18, 12) do
      [ 3, 2, 1 ].each { |offset| complete_practice(@user, Date.current - offset) }
      assert_equal 3, @user.streak
      complete_practice(@user)
      assert_equal 4, @user.streak
      assert_equal 4, @user.streak(today: Date.tomorrow)
      assert_equal 0, @user.streak(today: Date.current + 2)
    end
  end

  test "a missed date breaks the streak" do
    complete_practice(@user, Date.current - 3)
    complete_practice(@user)
    assert_equal 1, @user.streak
  end

  test "non audio empty oversized and invalid duration uploads are rejected" do
    practice = @user.daily_practices.build(daily_question: question_for, practiced_on: Date.current, completed_at: Time.current, duration_ms: 0)
    practice.audio.attach(io: StringIO.new("text"), filename: "fake.txt", content_type: "text/plain")
    assert_not practice.valid?
    assert practice.errors[:audio].any?
    assert practice.errors[:duration_ms].any?
    practice.audio.blob.content_type = "audio/wav"
    practice.audio.blob.byte_size = 11.megabytes
    practice.duration_ms = 60001
    assert_not practice.valid?
    assert practice.errors[:audio].any?
    practice.audio.blob.byte_size = 0
    assert_not practice.valid?
  end

  test "account deletion removes practices and schedules audio purge" do
    practice = complete_practice(@user)
    blob = practice.audio.blob
    perform_enqueued_jobs { @user.destroy! }
    assert_not DailyPractice.exists?(practice.id)
    assert_not ActiveStorage::Blob.exists?(blob.id)
  end
end
