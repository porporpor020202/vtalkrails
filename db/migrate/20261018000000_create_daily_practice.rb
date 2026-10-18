class CreateDailyPractice < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_questions do |t|
      t.date :asked_on, null: false
      t.string :question, null: false
      t.string :source, null: false
      t.timestamps
    end
    add_index :daily_questions, :asked_on, unique: true

    create_table :daily_practices do |t|
      t.references :user, null: false, foreign_key: true
      t.references :daily_question, null: false, foreign_key: true
      t.date :practiced_on, null: false
      t.integer :duration_ms, null: false
      t.datetime :completed_at, null: false
      t.timestamps
    end
    add_index :daily_practices, [ :user_id, :practiced_on ], unique: true
  end
end
