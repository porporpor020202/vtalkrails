module GoogleOauthTestConfig
  GOOGLE_LOGIN_ORIGINS = [
    "http://localhost:3000",
    "https://dev.sayonething.net",
    "https://www.sayonething.net",
    "https://sayonething.net"
  ].map(&:freeze).freeze
end
