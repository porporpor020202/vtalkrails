require "test_helper"

class AdminAccessTest < ActionDispatch::IntegrationTest
  test "r_지정한 이메일의 사용자는 Google과 Apple 로그인 모두 관리자 페이지에 진입할 수 있다" do
    [ users(:korean_native), users(:english_native) ].each do |user|
      user.update!(
        email_address: "porporpor020202@gmail.com",
        admin: false
      )
      sign_in_as(user)

      refute user.reload.admin?

      get admin_feedbacks_path

      assert_response :success
      assert user.reload.admin?
    end
  end

  test "r_다른 이메일의 사용자는 요청값을 조작해도 관리자로 승격되지 않는다" do
    user = users(:english_native)
    user.update!(
      email_address: "ordinary-user@example.com",
      admin: false
    )
    sign_in_as(user)

    get admin_feedbacks_path, params: {
      email_address: "porporpor020202@gmail.com",
      admin: true
    }

    assert_response :forbidden
    refute user.reload.admin?
  end
end
