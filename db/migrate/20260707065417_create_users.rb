class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :oauth_provider, null: false
      t.string :oauth_uid, null: false
      t.string :email_address, null: false
      t.string :display_name, null: true
      t.string :native_language, null: true

      t.timestamps null: false
    end

    add_index :users, :display_name, unique: true
    add_index :users, [ :oauth_provider, :oauth_uid ], unique: true
  end
end
