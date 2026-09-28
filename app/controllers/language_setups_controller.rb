class LanguageSetupsController < ApplicationController
  skip_before_action :require_language_setup
  before_action :load_languages

  def show
    redirect_to rooms_path(tab: "learning") if current_user.language_setup_complete?
  end

  def update
    current_user.assign_attributes(params.require(:user).permit(:mother_language_id, :learning_language_id))
    if current_user.save(context: :language_setup)
      redirect_to rooms_path(tab: "learning"), status: :see_other
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def load_languages
    @languages = Language.order(:code)
    @hide_bottom_nav = true
  end
end
