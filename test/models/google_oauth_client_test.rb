require "test_helper"
require "minitest/mock"

class GoogleOauthClientTest < ActiveSupport::TestCase
  setup do
    if GoogleOauthClient.respond_to?(:mocked_mode_enabled=)
      GoogleOauthClient.mocked_mode_enabled = false
    end
    @client = GoogleOauthClient.new
    @claims = {
      "sub" => "google-nonce-user",
      "email" => "nonce@example.com",
      "email_verified" => true,
      "nonce" => "expected-nonce"
    }
  end

  test "web authentication accepts a matching nonce" do
    result = authenticate_with_claims
    assert_equal({ uid: "google-nonce-user", email: "nonce@example.com" }, result)
  end

  test "web authentication rejects an incorrect token nonce" do
    @claims["nonce"] = "different-nonce"
    error = assert_raises(GoogleOauthClient::AuthenticationError) { authenticate_with_claims }
    assert_equal "Nonce verification failed", error.message
  end

  test "web authentication rejects a missing token nonce" do
    @claims.delete("nonce")
    error = assert_raises(GoogleOauthClient::AuthenticationError) { authenticate_with_claims }
    assert_equal "Nonce verification failed", error.message
  end

  test "web authentication rejects a missing expected nonce even when token nonce is absent" do
    @claims.delete("nonce")
    assert_raises(GoogleOauthClient::AuthenticationError) { authenticate_with_claims(nonce: nil) }
  end

  private

  def authenticate_with_claims(nonce: "expected-nonce")
    @client.stub(:exchange_code_for_tokens, { "id_token" => "test-token" }) do
      @client.stub(:decode_id_token, @claims) do
        @client.authenticate(code: "test-code", redirect_uri: "https://example.com/callback", nonce: nonce)
      end
    end
  end
end
