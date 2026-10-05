require "stringio"
require "rack/test"

module VoiceTestHelper
  def voice_audio
    @voice_audio ||= begin
      rate = 8_000
      samples = Array.new(rate * 2) do |index|
        (Math.sin(2 * Math::PI * 440 * index / rate) * 4_000).round
      end.pack("s<*")
      "RIFF".b + [36 + samples.bytesize].pack("V") + "WAVEfmt ".b +
        [16, 1, 1, rate, rate * 2, 2, 16].pack("VvvVVvv") +
        "data".b + [samples.bytesize].pack("V") + samples
    end
  end

  def voice_upload
    Rack::Test::UploadedFile.new(
      StringIO.new(voice_audio), "audio/wav", true, original_filename: "voice.wav"
    )
  end

  def create_voice_message(room:, sender:)
    message = room.voice_messages.build(sender: sender, duration_ms: 2_000)
    message.audio.attach(io: StringIO.new(voice_audio), filename: "voice.wav", content_type: "audio/wav")
    message.save!
    message
  end
end
