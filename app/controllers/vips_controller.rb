class VipsController < ApplicationController
  before_action :private_response

  rescue_from Billing::Error do |error|
    render json: { error: error.message }, status: :unprocessable_entity
  end

  def show
    @subscriptions = current_user.vip_subscriptions.order(created_at: :desc)
    @provider = ios_app? ? "apple" : android_app? ? "google" : "paddle"
    @product_id = ENV[@provider == "apple" ? "APPLE_VIP_PRODUCT_ID" : "GOOGLE_VIP_PRODUCT_ID"]
    @price = Billing::Paddle.price if @provider == "paddle" && ENV["PADDLE_API_KEY"].present? && ENV["PADDLE_CLIENT_TOKEN"].present?
  rescue Billing::Error
    @billing_unavailable = true
  end

  def checkout
    return head :forbidden if native_app?
    current_user.with_lock do
      return render(json: { error: "You already have VIP. Manage your existing subscription." }, status: :conflict) if current_user.vip?
      transaction = Billing::Paddle.checkout(current_user)
      render json: { transaction_id: transaction.fetch("id") }
    end
  end

  def verify
    provider = params[:provider].to_s
    return head :unprocessable_entity unless %w[apple google].include?(provider)
    subscription = Billing::Sync.call(provider, params[:purchase_reference].to_s, expected_user: current_user)
    render json: { vip: current_user.vip?, subscription_status: subscription.status }
  end

  def status
    render json: { vip: current_user.vip? }
  end

  def terms
  end

  def manage
    subscription = current_user.vip_subscriptions.find(params[:subscription_id])
    # Native customers manage their purchase in its originating store.
    if subscription.provider == "paddle" && !native_app?
      url = Billing::Paddle.portal(subscription)
      raise Billing::Error, "Billing portal is unavailable." unless url.present? && URI(url).scheme == "https"
      redirect_to url, allow_other_host: true
    else
      redirect_to vip_path, notice: "Manage this subscription using the service where you purchased it."
    end
  end

  private

  def private_response
    response.headers["Cache-Control"] = "no-store"
  end
end
