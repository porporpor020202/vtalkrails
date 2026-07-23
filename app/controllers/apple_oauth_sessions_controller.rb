class AppleOauthSessionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :callback, :native_authenticate ]
  allow_unauthenticated_access
  before_action :verify_oauth_state, only: [ :callback ]
  before_action :verify_oauth_nonce, only: [ :callback ]

  def native_authenticate
    identity_token = params[:identity_token]
    if identity_token.blank?
      render json: { error: "Missing identity token" }, status: :bad_request
      return
    end

    oauth_client = AppleOauthClient.new
    begin
      user_info = oauth_client.decode_id_token(identity_token)
      uid = user_info["sub"]
      email = user_info["email"]

      if uid.blank?
        render json: { error: "Invalid identity token: missing sub" }, status: :unprocessable_entity
        return
      end

      user = OauthUserService.find_or_create(
        oauth_provider: :apple,
        current_user: authenticated? ? current_user : nil,
        uid: uid,
        email: email
      )

      if user.persisted?
        token = user.signed_id(purpose: :native_auth, expires_in: 5.minutes)
        render json: { token: token }
      else
        render json: { error: "Unable to create or find user: #{user.errors.full_messages.join(', ')}" }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Native Apple Auth failed: #{e.class} - #{e.message}"
      render json: { error: "Authentication failed" }, status: :unprocessable_entity
    end
  end

  def new
    render :new, layout: false
  end

  def create
    nonce = SecureRandom.urlsafe_base64(16)
    state = SecureRandom.hex(24) + ":" + params[:platform]
    redirect_uri = callback_apple_oauth_sessions_url

    secure_cookie = Rails.env.production? || request.ssl?
    cookies.encrypted[:apple_oauth_state] = { same_site: :none, expires: 1.hour.from_now, secure: secure_cookie, value: state }
    cookies.encrypted[:apple_oauth_nonce] = { same_site: :none, expires: 1.hour.from_now, secure: secure_cookie, value: nonce }

    oauth_client = AppleOauthClient.new
    authorization_url = oauth_client.authorization_url(
      state: state,
      nonce: nonce,
      redirect_uri: redirect_uri
    )

    redirect_to authorization_url, allow_other_host: true
  end

  def callback
    user_info = authenticate_with_apple
    user = create_user(user_info)
    unless user.persisted?
      redirect_to new_session_path, alert: "Unable to sign in. Please try again."
      return
    end

    platform = params[:state].split(":").last
    if platform == "native"
      token = user.signed_id(purpose: :native_auth, expires_in: 5.minutes)
      redirect_to "vtalk://auth-callback?token=#{token}&platform=#{platform}", allow_other_host: true
    else
      sign_in_and_redirect_user(user)
    end
  rescue AppleOauthClient::AuthenticationError => e
    Rails.logger.error "Apple OAuth authentication error: #{e.message}"
    redirect_to new_session_path, alert: "Unable to sign in. Please try again."
  rescue => e
    Rails.logger.error "Apple OAuth callback error: #{e.class} - #{e.message}"
    redirect_to new_session_path, alert: "Unable to sign in. Please try again."
  end

  def authenticate_by_token
    user = User.find_signed(params[:token], purpose: :native_auth)

    if user
      sign_in_and_redirect_user(user)
    else
      redirect_to new_session_path, alert: "Unable to sign in. Please try again."
    end
  end

  private

  def authenticate_with_apple
    oauth_client = AppleOauthClient.new
    oauth_client.authenticate(
      code: params[:code],
      redirect_uri: callback_apple_oauth_sessions_url,
      nonce: stored_nonce
    )
  end

  def create_user(user_info)
    OauthUserService.find_or_create(
      oauth_provider: :apple,
      current_user: authenticated? ? current_user : nil,
      uid: user_info[:uid],
      email: user_info[:email]
    )
  end

  def verify_oauth_state
    stored_state = cookies.encrypted[:apple_oauth_state]
    cookies.delete(:apple_oauth_state)
    unless stored_state.present? && params[:state].present? && ActiveSupport::SecurityUtils.secure_compare(params[:state], stored_state)
      redirect_to new_session_path, alert: "Invalid request. Please try again."
    end
  end

  def verify_oauth_nonce
    unless stored_nonce.present?
      redirect_to new_session_path, alert: "Invalid request. Please try again."
    end
  end

  def sign_in_and_redirect_user(user)
    start_new_session_for user
    redirect_to after_authentication_url
  end

  def stored_nonce
    return @stored_nonce if defined?(@stored_nonce)
    @stored_nonce = cookies.encrypted[:apple_oauth_nonce]
    cookies.delete(:apple_oauth_nonce)
    @stored_nonce
  end
end
