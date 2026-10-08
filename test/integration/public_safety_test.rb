require "test_helper"

class PublicSafetyTest < ActionDispatch::IntegrationTest
  test "로그인하지 않아도 아동 안전 정책과 연락처를 볼 수 있다" do
    get child_safety_path

    assert_response :success
    assert_select "h1", text: "Child Safety Standards"

    # 문서 제목만 존재하는 상태를 방지한다. 연령 제한, 금지 행위,
    # 신고 방법과 실제 연락 수단까지 공개되어야 한다.
    assert_match "at least 18 years old", response.body
    assert_match "Child Sexual Abuse and Exploitation", response.body
    assert_match "Child Sexual Abuse Material", response.body
    assert_match "Reporting a Child Safety Concern", response.body
    assert_match "Designated Child Safety Point of Contact", response.body
    assert_select "a[href^='mailto:']", text: /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/, minimum: 1
  end

  test "공개 지원 페이지에서 연락처와 안전 정책과 개인정보 정책에 접근할 수 있다" do
    get support_path

    assert_response :success
    assert_select "a[href='#{child_safety_path}']", text: "Child Safety Standards"
    assert_select "a[href='#{privacy_path}']", text: "Privacy Policy"
    assert_select "a[href^='mailto:']", text: /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/, minimum: 1
  end
end
