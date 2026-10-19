class SettingsController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session
  def show
  end
end
