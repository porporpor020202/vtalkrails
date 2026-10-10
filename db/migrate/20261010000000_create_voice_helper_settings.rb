class CreateVoiceHelperSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :voice_helper_settings do |t|
      t.string :model_key, null: false, default: "gemini-2.5-flash-lite"
      t.integer :estimated_users, null: false, default: 2000
      t.integer :daily_uses, null: false, default: 5
      t.integer :audio_seconds, null: false, default: 10
      t.decimal :usd_to_krw, precision: 10, scale: 2, null: false, default: 1341
      t.timestamps
    end
  end
end
