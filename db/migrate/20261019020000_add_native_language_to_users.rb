class AddNativeLanguageToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :native_language, :string
    add_check_constraint :users, "native_language IS NULL OR native_language IN ('ko', 'en', 'ja', 'zh', 'es')", name: "users_native_language_supported"
  end
end
