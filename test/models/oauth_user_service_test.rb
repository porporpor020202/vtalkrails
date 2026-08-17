require "test_helper"

class OauthUserServiceTest < ActiveSupport::TestCase
  test "same email with different providers creates separate users" do
    email = "same-email@example.com"

    apple_user = OauthUserService.find_or_create(
      oauth_provider: :apple,
      uid: "apple-user-1",
      email: email
    )
    google_user = OauthUserService.find_or_create(
      oauth_provider: :google,
      uid: "google-user-1",
      email: email
    )

    assert apple_user.persisted?
    assert google_user.persisted?
    assert_not_equal apple_user.id, google_user.id
    assert_equal 2, User.where(email_address: email).count
  end

  test "same provider identity always returns the same user" do
    first = OauthUserService.find_or_create(
      oauth_provider: :google,
      uid: "google-user-2",
      email: "first@example.com"
    )
    second = OauthUserService.find_or_create(
      oauth_provider: :google,
      uid: "google-user-2",
      email: "updated@example.com"
    )

    assert_equal first.id, second.id
    assert_equal "first@example.com", second.email_address
  end

  test "same uid from different providers remains separate" do
    apple_user = OauthUserService.find_or_create(
      oauth_provider: :apple,
      uid: "shared-looking-uid",
      email: "apple@example.com"
    )
    google_user = OauthUserService.find_or_create(
      oauth_provider: :google,
      uid: "shared-looking-uid",
      email: "google@example.com"
    )

    assert_not_equal apple_user.id, google_user.id
  end
end
