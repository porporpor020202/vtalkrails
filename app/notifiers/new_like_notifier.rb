class NewLikeNotifier < ApplicationNotifier
  required_param :hike

  deliver_by :ios do |config|
    config.device_tokens = -> {
      recipient.notification_tokens.where(platform: :ios).pluck(:token)
    }

    config.format = ->(apn) {
      apn.alert = "Someone liked your hike!"
      apn.custom_payload = {
        path: hike_path(params[:hike])
      }
    }

    credentials = Rails.application.credentials.ios
    config.bundle_identifier = credentials.bundle_identifier
    config.key_id = credentials.key_id
    config.team_id = credentials.team_id
    config.apns_key = credentials.apns_key

    config.development = Rails.env.local?
  end
end
