class NotificationTokensController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    token_record = NotificationToken.find_or_initialize_by(token: notification_token[:token])
    token_record.update!(
      user: current_user,
      platform: notification_token[:platform]
    )
    head :created
  end

  def test_push
    tokens = current_user.notification_tokens
    if tokens.empty?
      redirect_to rooms_path, notice: "No notification token is registered. Open the app on your device first."
    else
      # Notifier를 통한 실제 APNs 및 FCM 전송 (모든 플랫폼)
      begin
        TestPushNotifier.with(message: "🔔 This is a test notification.", path: mypage_path).deliver(current_user)
        platforms = tokens.pluck(:platform).uniq.map(&:upcase).join(", ")
        redirect_to rooms_path, notice: "The notification was sent to: #{platforms}."
      rescue => e
        Rails.logger.error "[Push Test Error] #{e.message}\n#{e.backtrace&.join("\n")}"
        redirect_to rooms_path, alert: "Unable to send the notification: #{e.message}"
      end
    end
  end



  private
    def notification_token
      params.require(:notification_token).permit(:token, :platform)
    end
end

