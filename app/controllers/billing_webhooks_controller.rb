class BillingWebhooksController < ActionController::API
  rescue_from Billing::Error do
    head :service_unavailable
  end
  rescue_from Billing::InvalidPurchase, JSON::ParserError, ArgumentError, KeyError do
    head :bad_request
  end

  def paddle
    return head :payload_too_large if request.raw_post.bytesize > 256_000
    Billing::Paddle.verify_webhook!(request.raw_post, request.headers["Paddle-Signature"])
    payload = JSON.parse(request.raw_post)
    return head :ok unless payload.fetch("event_type").start_with?("subscription.")
    enqueue("paddle", payload.fetch("event_id"), payload.fetch("data").fetch("id"))
  end

  def apple
    return head :payload_too_large if request.raw_post.bytesize > 256_000
    payload = Billing::Apple.notification(params.require(:signedPayload))
    signed = payload.dig("data", "signedTransactionInfo")
    return head :ok if payload["notificationType"] == "TEST"
    transaction = JWT.decode(signed, nil, false).first
    enqueue("apple", payload.fetch("notificationUUID"), transaction.fetch("originalTransactionId"))
  rescue JWT::DecodeError
    head :bad_request
  end

  def google
    return head :payload_too_large if request.raw_post.bytesize > 256_000
    Billing::Google.verify_webhook!(request.headers["Authorization"])
    message = params.require(:message)
    data = JSON.parse(Base64.strict_decode64(message.fetch(:data)))
    return head :bad_request unless data["packageName"] == Billing::Config.get("GOOGLE_PLAY_PACKAGE_NAME")
    return head :ok if data["testNotification"]
    reference = data.dig("subscriptionNotification", "purchaseToken") || data.dig("voidedPurchaseNotification", "purchaseToken")
    return head :ok unless reference
    enqueue("google", message.fetch(:messageId), reference)
  end

  private

  def enqueue(provider, id, reference)
    event = BillingEvent.create_or_find_by!(provider: provider, event_id: id) { |record| record.reference = reference }
    BillingEventJob.perform_later(event.id) unless event.processed_at
    head :ok
  end
end
