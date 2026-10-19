class CreateDailyQuestions < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_questions do |t|
      t.date :asked_on, null: false
      t.string :question, null: false
      t.string :source, null: false
      t.timestamps
    end
    add_index :daily_questions, :asked_on, unique: true
  end
end
