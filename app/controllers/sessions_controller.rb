class SessionsController < ApplicationController
  skip_before_action :require_onboarding
  allow_unauthenticated_access only: :new

  def new
    return unless authenticated?

    redirect_to(
      current_user.onboarding_complete? ? root_path : onboarding_path,
      status: :see_other
    )
  end

  def destroy
    terminate_session
    redirect_to new_session_path, notice: "You have signed out.", status: :see_other
  end
end
