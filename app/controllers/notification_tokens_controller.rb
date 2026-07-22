class NotificationTokensController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    current_user.notification_tokens.find_or_create_by!(notification_token)
    head :created
  end

  def test_push
    tokens = current_user.notification_tokens.where(platform: :ios).pluck(:token)
    if tokens.empty?
      redirect_to rooms_path, notice: "등록된 iOS 푸시 토큰이 없습니다."
    else
      # Notifier를 통한 실제 APNs 발송 (세팅 페이지 경로 지정)
      begin
        TestPushNotifier.with(message: "🔔 테스트 푸시 알림입니다!", path: settings_path).deliver(current_user)
        redirect_to rooms_path, notice: "푸시 알림을 발송했습니다."
      rescue => e
        Rails.logger.error "[Push Test Error] #{e.message}"
        redirect_to rooms_path, alert: "푸시 전송 실패: #{e.message}"
      end
    end
  end



  private
    def notification_token
      params.require(:notification_token).permit(:token, :platform)
    end
end


