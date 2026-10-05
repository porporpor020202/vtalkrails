class CreateRooms < ActiveRecord::Migration[8.1]
  def change
    create_table :rooms do |t|
      t.references :host, null: false, foreign_key: { to_table: :users }
      t.references :opponent, null: false, foreign_key: { to_table: :users }
      t.references :language, null: false, foreign_key: true

      t.timestamps

      t.index [ :host_id, :opponent_id ]
    end
  end
end
