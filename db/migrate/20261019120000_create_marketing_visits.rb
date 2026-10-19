class CreateMarketingVisits < ActiveRecord::Migration[8.1]
  def change
    create_table :marketing_visits do |t|
      t.string :visitor_key, null: false
      t.references :user, foreign_key: true
      t.datetime :started_at, null: false
      t.datetime :last_seen_at, null: false
      t.string :source, null: false
      t.string :medium, null: false
      t.string :campaign
      t.string :content
      t.string :referrer_host
      t.string :landing_path, null: false
      t.string :platform, null: false
      t.boolean :internal, default: false, null: false
    end
    add_index :marketing_visits, [ :visitor_key, :started_at ]
    add_index :marketing_visits, [ :started_at, :source, :campaign ]
    add_index :marketing_visits, :last_seen_at
  end
end
