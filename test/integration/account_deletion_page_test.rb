require "test_helper"

class AccountDeletionPageTest < ActionDispatch::IntegrationTest
  test "account deletion information is public and identifies the app and deletion policy" do
    get delete_account_path

    assert_response :success
    assert_select "h1", text: "Account and Data Deletion"
    assert_select "a[href='#{confirm_account_deletion_path}']", text: /Start account deletion/
    assert_select "#deleted-data", text: "Data that will be deleted"
    assert_select "#retained-data", text: "Data retained for an additional period"
    assert_select "a[href='#{privacy_path}']", text: "Privacy Policy"
  end

  test "confirmation requires authentication and preserves its return URL" do
    get confirm_account_deletion_path

    assert_redirected_to new_session_path
    assert_equal "http://www.example.com#{confirm_account_deletion_path}", session[:return_to_after_authenticating]
  end

  test "authenticated user can review the account before deleting it" do
    user = users(:one)
    sign_in_as user

    get confirm_account_deletion_path

    assert_response :success
    assert_select "dd", text: user.email_address
    assert_select "form[action='#{account_path}'][method='post']"
    assert_select "input[name='_method'][value='delete']"
  end
end
