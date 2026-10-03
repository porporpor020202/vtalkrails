class SessionsController < ApplicationController
  allow_unauthenticated_access only: :new

  def new
  end

  def destroy
    terminate_session
    redirect_to new_session_path, notice: "You have signed out.", status: :see_other
  end
end
