# https://developers.google.com/identity/openid-connect/openid-connect
class GoogleOauthSessionsController < ApplicationController
  skip_before_action :require_language_setup
  skip_before_action :verify_authenticity_token, only: [ :callback, :native_authenticate ]
  allow_unauthenticated_access

  def native_authenticate
    identity_token = params[:identity_token]
    nonce = params[:nonce]
    if identity_token.blank? || nonce.blank?
      render json: { error: "Missing identity token or nonce" }, status: :bad_request
      return
    end

    user_info = GoogleOauthClient.new.authenticate_id_token(identity_token, nonce: nonce)
    user = OauthUserService.find_or_create(
      oauth_provider: :google,
      uid: user_info[:uid],
      email: user_info[:email]
    )

    if user.persisted?
      token = user.signed_id(purpose: :native_auth, expires_in: 5.minutes)
      render json: { token: token }
    else
      render json: { error: "Unable to create or find user" }, status: :unprocessable_entity
    end
  rescue GoogleOauthClient::AuthenticationError => e
    Rails.logger.error "Native Google authentication failed: #{e.message}"
    render json: { error: "Authentication failed" }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "Native Google authentication error: #{e.class} - #{e.message}"
    render json: { error: "Authentication failed" }, status: :unprocessable_entity
  end

  def new
    render :new, layout: false
  end

  def create
    client_id = Rails.application.credentials.dig(:google, :client_id)
    callback_uri = callback_google_oauth_sessions_url

    platform = params[:platform] == "native" ? "native" : "web"
    state = SecureRandom.hex(24) + ":" + platform
    nonce = SecureRandom.urlsafe_base64(16)
    session[:google_oauth_state] = state
    session[:google_oauth_nonce] = nonce

    query = {
      client_id: client_id,
      redirect_uri: callback_uri,
      response_type: "code",
      scope: "openid email profile",
      state: state,
      nonce: nonce
    }.to_query
    redirect_url = "https://accounts.google.com/o/oauth2/v2/auth?#{query}"
    redirect_to redirect_url, allow_other_host: true
  end

  def callback
    request_state = params[:state]
    session_state = session.delete(:google_oauth_state)
    session_nonce = session.delete(:google_oauth_nonce)
    unless request_state.present? && session_state.present? && ActiveSupport::SecurityUtils.secure_compare(request_state, session_state)
      redirect_to new_session_path, alert: "Invalid request. Please try again."
      return
    end

    if params[:error].present? || params[:code].blank?
      redirect_to new_session_path, alert: "Sign in was not completed. Please try again."
      return
    end

    if session_nonce.blank?
      redirect_to new_session_path, alert: "Invalid request. Please try again."
      return
    end

    # Exchange code for tokens and decode ID token
    oauth_client = GoogleOauthClient.new
    user_info = oauth_client.authenticate(
      code: params[:code],
      redirect_uri: callback_google_oauth_sessions_url,
      nonce: session_nonce
    )

    # Create or find the user
    @user = OauthUserService.find_or_create(
      oauth_provider: :google,
      uid: user_info[:uid],
      email: user_info[:email]
    )
    unless @user.persisted?
      Rails.logger.error "Google OAuth user creation failed: #{@user.errors.full_messages}"
      redirect_to new_session_path, alert: "Unable to sign in. Please try again."
      return
    end

    platform = params[:state].split(":").last
    if platform == "native"
      token = @user.signed_id(purpose: :native_auth, expires_in: 5.minutes)
      redirect_to "vtalk://auth-callback?token=#{token}&platform=#{platform}", allow_other_host: true
    else
      sign_in_and_redirect_user(@user)
    end
  rescue GoogleOauthClient::AuthenticationError => e
    Rails.logger.error "Google OAuth authentication error: #{e.message}"
    redirect_to new_session_path, alert: "Unable to sign in. Please try again."
  rescue => e
    Rails.logger.error "Google OAuth callback error: #{e.class} - #{e.message}"
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

  def sign_in_and_redirect_user(user)
    start_new_session_for user
    redirect_to after_authentication_url
  end
end
