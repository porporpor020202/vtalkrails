class SessionsController < ApplicationController
  allow_unauthenticated_access only: :new

  def new
    redirect_to root_path, status: :see_other if authenticated?
  end

  def destroy
    terminate_session
    redirect_to new_session_path, notice: "로그아웃했어요.", status: :see_other
  end
end
