class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email_address
      t.string :password_digest
      t.string :oauth_provider
      t.string :oauth_uid
      t.boolean :guest, default: false, null: false
      t.string :name
      t.string :icon

      t.timestamps
    end
    add_index :users, :email_address, unique: true, where: "email_address IS NOT NULL"
    add_index :users, [ :oauth_provider, :oauth_uid ], unique: true, where: "oauth_provider IS NOT NULL AND oauth_uid IS NOT NULL"
  end
end
