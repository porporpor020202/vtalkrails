class AiTranscript < ApplicationRecord
  belongs_to :blob, class_name: "ActiveStorage::Blob"

  def self.for_audio(blob)
    record = create_or_find_by!(blob: blob)
    record.with_lock do
      if record.text.nil?
        transcript = blob.open { |file| Ai::Client.new.transcribe(file) }
        raise Ai::Client::Error, "No speech detected" if transcript.blank?
        record.update!(text: transcript)
      end
      record.text
    end
  end
end
