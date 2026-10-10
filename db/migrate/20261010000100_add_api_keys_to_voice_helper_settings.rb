class AddApiKeysToVoiceHelperSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :voice_helper_settings, :gemini_api_key, :text
    add_column :voice_helper_settings, :openai_api_key, :text
    add_column :voice_helper_settings, :groq_api_key, :text
  end
end
