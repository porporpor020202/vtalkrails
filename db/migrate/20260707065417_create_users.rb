class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :oauth_provider, null: false
      t.string :oauth_uid, null: false
      t.string :email_address, null: false
      t.string :native_language
      t.datetime :last_active_at
      t.timestamps
    end
    add_index :users, [ :oauth_provider, :oauth_uid ], unique: true
    add_index :users, :last_active_at
  end
end
