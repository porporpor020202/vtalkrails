class Admin::SuspensionsController < Admin::BaseController
  def create
    user = User.find(params[:user_id])
    user.update!(suspended_at: Time.current)
    redirect_back fallback_location: admin_content_reports_path, notice: "User suspended."
  end
end
