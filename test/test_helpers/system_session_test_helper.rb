module SystemSessionTestHelper
  def sign_in(user:)
    previous_session_ids = user.sessions.pluck(:id)
    token = user.signed_id(purpose: :native_auth, expires_in: 5.minutes)

    path =
      case user.oauth_provider
      when "google"
        authenticate_by_token_google_oauth_sessions_path(token: token)
      when "apple"
        authenticate_by_token_apple_oauth_sessions_path(token: token)
      else
        raise ArgumentError, "Unsupported sign-in provider: #{user.oauth_provider}"
      end

    visit path

    new_sessions = user.sessions.where.not(id: previous_session_ids)

    Selenium::WebDriver::Wait.new(timeout: 5).until do
      new_sessions.exists?
    end

    assert_equal 1, new_sessions.count, "A sign-in session must be created."

    new_sessions.first!
  end
end
