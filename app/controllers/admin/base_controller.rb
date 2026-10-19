class Admin::BaseController < ApplicationController
  before_action :require_admin
  before_action { response.headers["Cache-Control"] = "private, no-store" }

  private

  def require_admin
    head :forbidden unless current_user.admin?
  end
end
