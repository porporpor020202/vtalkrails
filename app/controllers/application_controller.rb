class ApplicationController < ActionController::Base
  include Authentication
  before_action :track_user_activity
  stale_when_importmap_changes
  helper_method :native_app?, :android_app?, :ios_app?

  private

  def track_user_activity
    return unless authenticated?
    now = Time.current
    User.where(id: current_user.id).where("last_active_at IS NULL OR last_active_at < ?", 5.minutes.ago).update_all(last_active_at: now)
  end

  def native_app?
    android_app? || ios_app?
  end

  def android_app?
    request.user_agent.to_s.match?(/vtalk\/android\/|VtalkAndroid\//)
  end

  def ios_app?
    request.user_agent.to_s.match?(/vtalk\/ios\/|VtalkiOS\//)
  end
end
