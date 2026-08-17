class AccountsController < ApplicationController
  def destroy
    user = current_user
    terminate_session
    user.destroy!

    redirect_to new_session_path, notice: "Your account has been deleted.", status: :see_other
  end
end
