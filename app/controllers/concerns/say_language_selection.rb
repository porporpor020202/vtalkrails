module SayLanguageSelection
  extend ActiveSupport::Concern

  included do
    helper_method :selected_language_tab, :selected_say_language, :language_tab_path
  end

  private

  def selected_language_tab
    return @community_tab if @community_tab
    if params[:tab].present?
      raise ActiveRecord::RecordNotFound unless %w[learning mother].include?(params[:tab])
      return params[:tab]
    end
    if @room&.language_id.present?
      return "mother" if @room.language_id == current_user.mother_language_id
      return "learning" if @room.language_id == current_user.learning_language_id
    end
    session[:language_tab] == "mother" ? "mother" : "learning"
  end

  def language_tab_path(tab, language)
    if session[:conversation_mode] == "community" && language
      language_posts_path(language, tab: tab)
    else
      rooms_path(tab: tab)
    end
  end

  def selected_say_language
    selected_language_tab == "mother" ? current_user.mother_language : current_user.learning_language
  end
end
