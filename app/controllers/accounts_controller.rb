class AccountsController < ApplicationController
  def destroy
    user = current_user
    terminate_session
    AiUsage.clear_user_responses!(user)
    user.destroy!
    cookies.delete(:marketing_visitor_id)
    cookies.delete(:marketing_visit_id)

    redirect_to new_session_path, notice: t("ui.deleted"), status: :see_other
  end
end
