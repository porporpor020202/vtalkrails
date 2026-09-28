class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :oauth_provider, null: false
      t.string :oauth_uid, null: false
      t.string :email_address, null: false
      t.string :display_name, null: false
      t.string :time_zone
      t.datetime :last_active_at
      t.references :mother_language, foreign_key: { to_table: :languages }
      t.references :learning_language, foreign_key: { to_table: :languages }

      t.timestamps null: false

      t.index :display_name, unique: true
      t.index [ :oauth_provider, :oauth_uid ], unique: true
      t.index :last_active_at
      t.check_constraint "mother_language_id <> learning_language_id", name: "users_languages_must_differ"
    end

    create_table :user_activity_hours do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :hour, null: false
      t.integer :samples, null: false, default: 0
      t.timestamps
      t.index [:user_id, :hour], unique: true
      t.check_constraint "hour BETWEEN 0 AND 23", name: "user_activity_hour_range"
    end
  end
end
