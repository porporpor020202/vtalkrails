class ApplicationController < ActionController::Base
  include Authentication
  stale_when_importmap_changes
  helper_method :native_app?, :android_app?, :ios_app?

  private

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
