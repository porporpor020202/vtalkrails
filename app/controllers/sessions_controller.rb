class SessionsController < ApplicationController
  allow_unauthenticated_access only: :new

  def new
    redirect_to root_path, status: :see_other if authenticated?
  end

  def destroy
    terminate_session
    redirect_to new_session_path, notice: t("ui.logged_out"), status: :see_other
  end
end
