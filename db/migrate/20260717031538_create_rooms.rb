class CreateRooms < ActiveRecord::Migration[8.1]
  def change
    create_table :rooms do |t|
      t.references :user, null: false, foreign_key: true
      t.references :opponent, null: false, foreign_key: { to_table: :users }
      t.integer :status, null: false, default: 1

      t.timestamps
    end
  end
end
