require "test_helper"
require "minitest/mock"

class AiAssistanceJobTest < ActiveSupport::TestCase
  setup do
    @user = users(:korean_native)
    grant_vip(@user)
    @room = Room.create!(user: @user, opponent: users(:english_native), last_sender: users(:english_native))
    @message = @room.voice_messages.build(sender: users(:english_native), duration_ms: 1000)
    @message.audio.attach(io: File.open(file_fixture("sample.webm")), filename: "sample.webm", content_type: "audio/webm")
    @message.save!
    @assistance = AiAssistance.create!(user: @user, room: @room, source_message: @message,
      kind: "translation", native_language: "Korean", input_text: "안녕", request_key: SecureRandom.uuid)
  end

  test "stores output and does not execute a completed job again" do
    fake = Minitest::Mock.new
    fake.expect(:call, { "english" => "Hello", "ipa" => "/həˈloʊ/", "pronunciation_guide" => "헬로" })
    Ai::Assistant.stub(:new, ->(*) { fake }) do
      2.times { AiAssistanceJob.perform_now(@assistance.id) }
    end
    fake.verify
    assert_equal "completed", @assistance.reload.status
    assert_equal "Hello", @assistance.result["english"]
  end

  test "failure marks request failed without storing provider error details" do
    fake = Object.new
    def fake.call = raise(Ai::Client::Error, "private provider text")
    Ai::Assistant.stub(:new, ->(*) { fake }) { AiAssistanceJob.perform_now(@assistance.id) }
    assert_equal "failed", @assistance.reload.status
    assert_empty @assistance.result
  end

  test "a changed turn does not call the provider" do
    @room.update!(last_sender: @user)
    Ai::Assistant.stub(:new, ->(*) { flunk "must not call AI" }) do
      AiAssistanceJob.perform_now(@assistance.id)
    end
    assert_equal "failed", @assistance.reload.status
  end

  test "shared audio is transcribed once across messages" do
    fake = Minitest::Mock.new
    fake.expect(:transcribe, "How was your day?") { |file| file.respond_to?(:read) }
    Ai::Client.stub(:new, fake) do
      2.times { assert_equal "How was your day?", AiTranscript.for_audio(@message.audio.blob) }
    end
    fake.verify
    assert_equal 1, AiTranscript.where(blob: @message.audio.blob).count
  end

  test "empty transcription is not cached as successful speech" do
    fake = Minitest::Mock.new
    fake.expect(:transcribe, "") { |file| file.respond_to?(:read) }
    Ai::Client.stub(:new, fake) do
      assert_raises(Ai::Client::Error) { AiTranscript.for_audio(@message.audio.blob) }
    end
    assert_nil AiTranscript.find_by!(blob: @message.audio.blob).text
  end
end
