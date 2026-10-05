class CreateVoiceDrops < ActiveRecord::Migration[8.1]
  def change
    create_table :voice_drops do |t|
      t.references :sender, null: false, foreign_key: { to_table: :users }, index: false
      t.references :language, null: false, foreign_key: true, index: false
      t.string :request_key, null: false
      t.integer :recipient_count, null: false
      t.timestamps
    end

    add_index :voice_drops, [:sender_id, :request_key], unique: true
    add_index :voice_drops, :language_id
  end

end
