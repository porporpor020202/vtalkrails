class AllowVoiceConversationsWithoutLanguage < ActiveRecord::Migration[8.1]
  def change
    change_column_null :rooms, :language_id, true
    change_column_null :voice_drops, :language_id, true
  end
end
