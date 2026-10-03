class SettingsController < ApplicationController
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
end
