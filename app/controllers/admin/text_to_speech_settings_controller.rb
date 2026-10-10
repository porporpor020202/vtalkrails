class Admin::TextToSpeechSettingsController < Admin::BaseController
  def show
    @setting = TextToSpeechSetting.current
  end

  def update
    @setting = TextToSpeechSetting.current
    attributes = params.require(:text_to_speech_setting).permit(:model_key, :estimated_users, :daily_uses, :text_characters, :audio_seconds, :usd_to_krw,
      *TextToSpeechSetting::API_KEY_FIELDS).to_h
    TextToSpeechSetting::API_KEY_FIELDS.each do |field|
      attributes[field].present? ? attributes[field] = attributes[field].strip : attributes.delete(field)
    end
    if @setting.update(attributes)
      redirect_to admin_text_to_speech_setting_path, notice: "Read aloud settings saved. Changes apply to newly generated audio.", status: :see_other
    else
      render :show, status: :unprocessable_entity
    end
  end
end
