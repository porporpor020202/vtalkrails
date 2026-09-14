module GoogleOauthTestConfig
  GOOGLE_LOGIN_ORIGINS = [
    "http://localhost:3000"
    # "https://dev.vtalks.net",
    # "https://vtalks.net"
  ].map(&:freeze).freeze
end
