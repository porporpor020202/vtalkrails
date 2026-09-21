class AddUniqueUserIdentityIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :users, :display_name, unique: true
    add_index :users, [ :oauth_provider, :oauth_uid ], unique: true
  end
end
