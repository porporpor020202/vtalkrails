class CreateMarketingEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :marketing_events do |t|
      t.references :marketing_visit, foreign_key: true
      t.references :user, foreign_key: true
      t.string :name, null: false
      t.string :context, null: false, default: "daily"
      t.boolean :authenticated, null: false, default: false
      t.datetime :occurred_at, null: false
      t.string :deduplication_key, null: false
    end
    add_index :marketing_events, :deduplication_key, unique: true
    add_index :marketing_events, [ :name, :occurred_at ]
    add_index :marketing_events, [ :user_id, :occurred_at ]
  end
end
