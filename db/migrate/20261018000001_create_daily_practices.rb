class CreateDailyPractices < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_practices, if_not_exists: true do |t|
      t.references :user, null: true, foreign_key: true
      t.references :daily_question, null: false, foreign_key: true
      t.date :practiced_on, null: false
      t.integer :duration_ms, null: false
      t.datetime :completed_at, null: false
      t.timestamps
    end
    add_index :daily_practices, [ :user_id, :practiced_on ], unique: true, if_not_exists: true
  end
end
