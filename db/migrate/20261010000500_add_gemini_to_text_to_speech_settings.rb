class AddGeminiToTextToSpeechSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :text_to_speech_settings, :gemini_flash_api_key, :text
    add_column :text_to_speech_settings, :gemini_lite_api_key, :text
    add_column :text_to_speech_settings, :audio_seconds, :integer, null: false, default: 5
  end
end
