class CreateAiUsages < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_usages do |t|
      t.string :identity_key, null: false
      t.date :training_dates, array: true, null: false, default: []
      t.date :help_on
      t.jsonb :help_data, null: false, default: {}
      t.references :merged_into, foreign_key: { to_table: :ai_usages }
      t.timestamps
    end
    add_index :ai_usages, :identity_key, unique: true
  end
end
