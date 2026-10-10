class UpdateVoiceHelperDefaultModel < ActiveRecord::Migration[8.1]
  def up
    change_column_default :voice_helper_settings, :model_key, from: "gemini-2.5-flash-lite", to: "gemini-3.5-flash-lite"
    # Google's API rejects the previous default for newly connected accounts.
    execute "UPDATE voice_helper_settings SET model_key = 'gemini-3.5-flash-lite' WHERE model_key = 'gemini-2.5-flash-lite'"
  end

  def down
    change_column_default :voice_helper_settings, :model_key, from: "gemini-3.5-flash-lite", to: "gemini-2.5-flash-lite"
  end
end
