class LanguageSetupsController < ApplicationController
  def show
    @user = current_user
  end

  def update
    @user = current_user
    @user.update!(params.require(:user).permit(:native_language_id, :learning_language_id))
    redirect_to settings_path, status: :see_other
  end
end
