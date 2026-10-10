class CreateTextToSpeechSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :text_to_speech_settings do |t|
      t.string :model_key, null: false, default: "chirp3"
      %w[wavenet neural2 chirp3 tts1 tts1hd].each { |model| t.text "#{model}_api_key" }
      t.integer :estimated_users, null: false, default: 2000
      t.integer :daily_uses, null: false, default: 5
      t.integer :text_characters, null: false, default: 60
      t.decimal :usd_to_krw, precision: 10, scale: 2, null: false, default: 1341
      t.timestamps
    end
  end
end
