class LanguageSetupsController < ApplicationController
  def show
    @user = current_user
  end

  def update
    @user = current_user
    @user.assign_attributes(params.require(:user).permit(:native_language_id))

    if @user.save(context: :language_setup)
      redirect_to settings_path, status: :see_other
    else
      render :show, status: :unprocessable_entity
    end
  end
end
