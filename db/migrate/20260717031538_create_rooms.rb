class CreateRooms < ActiveRecord::Migration[8.1]
  def change
    create_table :rooms do |t|
      t.references :user, null: false, foreign_key: true
      t.references :opponent, null: false, foreign_key: { to_table: :users }
      t.references :last_sender, foreign_key: { to_table: :users }
      t.references :deleted_by, foreign_key: { to_table: :users }
      t.references :dismissed_by, foreign_key: { to_table: :users }
      t.integer :status, null: false, default: 1
      t.datetime :last_message_at

      t.timestamps

      t.index [ :user_id, :opponent_id ]
      t.index :last_message_at
    end
  end
end
