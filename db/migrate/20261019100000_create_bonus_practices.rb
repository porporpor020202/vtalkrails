class CreateBonusPractices < ActiveRecord::Migration[8.1]
  def change
    create_table :bonus_practices do |t|
      t.references :daily_practice, null: false, index: { unique: true }, foreign_key: true
      t.string :question, null: false
      t.string :source, null: false
      t.datetime :shared_at, null: false
      t.integer :duration_ms
      t.datetime :completed_at
      t.text :english_sentence
      t.timestamps
    end
  end
end
