class IsolateRoomsByNativeLanguage < ActiveRecord::Migration[8.1]
  def up
    rename_column :rooms, :language_id, :native_language_id
    rename_column :voice_drops, :language_id, :native_language_id

    execute <<~SQL
      UPDATE rooms
      SET native_language_id = COALESCE(
        (SELECT native_language_id FROM users WHERE users.id = rooms.host_id),
        (SELECT native_language_id FROM users WHERE users.id = rooms.opponent_id),
        native_language_id
      )
    SQL
    execute <<~SQL
      UPDATE voice_drops
      SET native_language_id = users.native_language_id
      FROM users WHERE users.id = voice_drops.sender_id
    SQL
  end

  def down
    rename_column :rooms, :native_language_id, :language_id
    rename_column :voice_drops, :native_language_id, :language_id
  end
end
