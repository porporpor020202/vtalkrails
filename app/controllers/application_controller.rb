class ApplicationController < ActionController::Base
  include Authentication
  before_action :require_onboarding
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :native_app?, :android_app?, :ios_app?

  private

  def require_onboarding
    return unless authenticated?
    return if current_user.onboarding_complete?

    redirect_to onboarding_path, status: :see_other
  end

  def native_app?
    android_app? || ios_app?
  end

  # TODO:앱스토어, 플레이스토어 업데이트 승인후에 레거시 제거할것.
  def android_app?
    agent = request.user_agent.to_s
    agent.include?("vtalk/android/") || agent.include?("VtalkAndroid/")
  end

  def ios_app?
    agent = request.user_agent.to_s
    agent.include?("vtalk/ios/") || agent.include?("VtalkiOS/")
  end
end
