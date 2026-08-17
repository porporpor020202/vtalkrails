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
      redirect_to rooms_path, notice: "등록된 푸시 토큰이 없습니다. (기기에서 앱을 실행해 주세요)"
    else
      # Notifier를 통한 실제 APNs 및 FCM 전송 (모든 플랫폼)
      begin
        TestPushNotifier.with(message: "🔔 테스트 푸시 알림입니다!", path: settings_path).deliver(current_user)
        platforms = tokens.pluck(:platform).uniq.map(&:upcase).join(", ")
        redirect_to rooms_path, notice: "푸시 알림을 발송했습니다. (전송 플랫폼: #{platforms})"
      rescue => e
        Rails.logger.error "[Push Test Error] #{e.message}\n#{e.backtrace&.join("\n")}"
        redirect_to rooms_path, alert: "푸시 전송 실패: #{e.message}"
      end
    end
  end



  private
    def notification_token
      params.require(:notification_token).permit(:token, :platform)
    end
end


