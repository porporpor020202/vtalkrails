module SayLanguageSelection
  private

  def selected_say_language
    @selected_say_language ||= if params[:language_id].present?
      Language.find(params[:language_id])
    else
      Language.find_by(id: session[:say_language_id]) || Language.find_by!(code: "en")
    end
  end
end
