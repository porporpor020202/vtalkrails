class NativeLanguagesController < ApplicationController
  allow_unauthenticated_access

  def show
  end

  def update
    language = params[:native_language].to_s
    unless NativeLanguage.supported?(language)
      render :show, status: :unprocessable_entity
      return
    end

    current_user&.update!(native_language: language)
    cookies.permanent[:native_language] = { value: language, httponly: true, same_site: request.ssl? ? :none : :lax, secure: request.ssl? }
    redirect_to root_path, status: :see_other
  end
end
