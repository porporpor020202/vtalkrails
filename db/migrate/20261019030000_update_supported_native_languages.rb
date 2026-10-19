class UpdateSupportedNativeLanguages < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :users, name: "users_native_language_supported"
    # English UI is no longer offered. Ask these users to choose again.
    execute "UPDATE users SET native_language = NULL WHERE native_language = 'en'"
    add_check_constraint :users, "native_language IS NULL OR native_language IN ('ko', 'ja', 'zh', 'zh-TW', 'es')", name: "users_native_language_supported"
  end

  def down
    remove_check_constraint :users, name: "users_native_language_supported"
    execute "UPDATE users SET native_language = NULL WHERE native_language = 'zh-TW'"
    add_check_constraint :users, "native_language IS NULL OR native_language IN ('ko', 'en', 'ja', 'zh', 'es')", name: "users_native_language_supported"
  end
end
