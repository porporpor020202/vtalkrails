class SettingsController < ApplicationController
  before_action :load_settings

  def show
  end

  def update
    current_user.assign_attributes(language_params)
    if current_user.save(context: :language_setup)
      redirect_to settings_path, notice: "Language settings saved.", status: :see_other
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def load_settings
    @languages = Language.order(:name)
    @child_safety_contact_email = ENV.fetch("PRIVACY_CONTACT_EMAIL", "privacy@vtalks.net")
  end

  def language_params
    params.require(:user).permit(:native_language_id)
  end
end
