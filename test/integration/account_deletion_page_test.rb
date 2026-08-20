require "test_helper"

class AccountDeletionPageTest < ActionDispatch::IntegrationTest
  test "account deletion information is public and identifies the app and deletion policy" do
    get delete_account_path

    assert_response :success
    assert_select "h1", text: "계정 및 데이터 삭제"
    assert_select "a[href='#{confirm_account_deletion_path}']", text: /계정 삭제 요청 시작/
    assert_select "#deleted-data", text: "삭제되는 데이터"
    assert_select "#retained-data", text: "추가 보관되는 데이터와 기간"
    assert_select "a[href='#{privacy_path}']", text: "개인정보처리방침"
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
