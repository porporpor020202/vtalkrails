class Admin::VoiceHelperSettingsController < Admin::BaseController
  def show
    @setting = VoiceHelperSetting.current
  end

  def update
    @setting = VoiceHelperSetting.current
    attributes = params.require(:voice_helper_setting).permit(:model_key, :estimated_users, :daily_uses, :audio_seconds, :usd_to_krw,
      :gemini_api_key, :openai_api_key, :groq_api_key, :prompt).to_h
    # Empty password fields preserve existing keys. Never echo a submitted key.
    %w[gemini_api_key openai_api_key groq_api_key].each do |name|
      if attributes[name].present?
        attributes[name] = attributes[name].strip
      else
        attributes.delete(name)
      end
    end
    if @setting.update(attributes)
      redirect_to admin_voice_helper_setting_path, notice: "Voice helper settings saved. Changes apply to the next request.", status: :see_other
    else
      render :show, status: :unprocessable_entity
    end
  end
end
