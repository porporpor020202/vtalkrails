return unless Rails.env.development?

account = User.find_by(email_address: "porporpor020202@gmail.com", oauth_provider: "google")
unless account
  puts "Development conversations skipped: Google demo account is missing."
  return
end

require "stringio"

# A playable two-second tone keeps development audio independent of external services.
sample_rate = 8_000
samples = Array.new(sample_rate * 2) do |index|
  (Math.sin(2 * Math::PI * 440 * index / sample_rate) * 3_000).round
end.pack("s<*")
audio = "RIFF".b + [36 + samples.bytesize].pack("V") + "WAVEfmt ".b +
  [16, 1, 1, sample_rate, sample_rate * 2, 2, 16].pack("VvvVVvv") +
  "data".b + [samples.bytesize].pack("V") + samples

languages = Language.enabled.where(code: %w[en es zh ja ko]).order(:code)
room_count = 0
message_count = 0

languages.each do |language|
  demo_users = %w[Panda Tiger Fox].each_with_index.map do |animal, index|
    user = User.find_or_initialize_by(oauth_provider: "google", oauth_uid: "development-demo-#{language.code}-#{index + 1}")
    user.assign_attributes(
      email_address: "demo-#{language.code}-#{index + 1}@example.test",
      display_name: "Demo #{language.label} #{animal}",
      native_language: language,
      age_group: "25_34",
      gender: %w[female male undisclosed][index],
      age_confirmed_at: user.age_confirmed_at || Time.current,
      onboarding_completed_at: user.onboarding_completed_at || Time.current,
      last_active_at: Time.current,
      receive_new_rooms: true
    )
    user.save!
    user
  end

  # Each language has two reply-ready rooms and one waiting for the partner.
  demo_users.each_with_index do |opponent, partner_index|
    host, guest = partner_index == 2 ? [opponent, account] : [account, opponent]
    count = [4, 5, 7][partner_index]
    room = Room.find_or_create_by!(host: host, opponent: guest, native_language: language)
    next if room.voice_messages.exists? || !room.active?

    Room.transaction do
      count.times do |index|
        message = room.voice_messages.build(
          sender: index.even? ? host : guest,
          duration_ms: 2_000,
          created_at: (count - index).minutes.ago
        )
        message.audio.attach(io: StringIO.new(audio), filename: "development-voice.wav", content_type: "audio/wav")
        message.save!
        message_count += 1
      end
    end
    room_count += 1
  end
end

puts "Development conversations for #{account.email_address} (Google): #{languages.count * 3} demo users, #{room_count} conversations populated, #{message_count} audio messages added."
