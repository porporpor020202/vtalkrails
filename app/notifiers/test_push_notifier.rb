class TestPushNotifier < ApplicationNotifier
  deliver_by :ios do |config|
    config.device_tokens = -> {
      recipient.notification_tokens.where(platform: :ios).pluck(:token)
    }

    config.format = ->(apn) {
      apn.alert = params[:message] || "🔔 This is a test notification."
      apn.custom_payload = {
        path: params[:path] || rooms_path
      }
    }

    credentials = Rails.application.credentials.ios
    if credentials.present?
      config.bundle_identifier = credentials.bundle_identifier
      config.key_id = credentials.key_id
      config.team_id = credentials.team_id
      config.apns_key = credentials.apns_key
    end

    config.development = true
  end

  deliver_by :fcm do |config|
    credentials = Rails.application.credentials.fcm
    config.credentials = credentials.present? ? credentials.to_h : {}

    config.device_tokens = -> {
      recipient.notification_tokens.where(platform: :fcm).pluck(:token)
    }
    config.json = -> (device_token) {
      {
        message: {
          token: device_token,
          notification: {
            title: "say one thing",
            body: params[:message] || "🔔 This is a test notification."
          },
          data: {
            path: params[:path] || rooms_path
          }
        }
      }
    }
  end
end
