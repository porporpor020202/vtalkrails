class RemoveVoiceAssistanceSettings < ActiveRecord::Migration[8.1]
  def up
    drop_table :text_to_speech_settings
    drop_table :voice_helper_settings
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
