class CreateVoiceMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :voice_messages do |t|
      t.references :room, null: false, foreign_key: true, index: false
      t.references :sender, null: false, foreign_key: { to_table: :users }, index: false
      t.references :voice_drop, foreign_key: true, index: false
      t.integer :duration_ms, null: false
      t.timestamps
    end

    add_index :voice_messages, :room_id
    add_index :voice_messages, :sender_id
    add_index :voice_messages, :voice_drop_id
  end

end
