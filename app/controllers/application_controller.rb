class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern


  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :track_user_activity

  helper_method :native_app?, :android_app?, :ios_app?

  protected

  def native_app?
    android_app? || ios_app?
  end

  def android_app?
    request.user_agent.to_s.include?("VtalkAndroid/")
  end

  def ios_app?
    request.user_agent.to_s.include?("VtalkiOS/")
  end

  private

  def track_user_activity
    return unless Current.user
    return if Current.user.last_active_at && Current.user.last_active_at > 5.minutes.ago

    Current.user.update_column(:last_active_at, Time.current)
  end
end
