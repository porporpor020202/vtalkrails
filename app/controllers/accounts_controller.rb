class AccountsController < ApplicationController
  def destroy
    user = current_user
    terminate_session
    user.destroy!

    redirect_to new_session_path, notice: "계정과 연결된 데이터가 삭제되었습니다.", status: :see_other
  end
end
