class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :native_app?, :android_app?, :ios_app?

  private

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
