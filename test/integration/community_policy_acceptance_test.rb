require "test_helper"

class CommunityPolicyAcceptanceTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:english_native)
    # 온보딩이 완료된 기존 계정으로 테스트하면 동의 화면을 건너뛰므로,
    # 아직 언어 설정을 하지 않은 신규 사용자 상태로 시작한다.
    @user.update!(native_language: nil)
    sign_in_as(@user)
  end

  test "온보딩에서 이용정책을 읽고 직접 동의할 수 있다" do
    get onboarding_path

    assert_response :success
    # 업로드 전에 사용자가 직접 동의해야 한다. 미리 체크된 체크박스나
    # 약관 링크만 보여주는 것으로 동의를 대신하지 않는다.
    assert_select "input[type='checkbox'][name='user[community_rules_accepted]']:not([checked])", count: 1
    assert_select "a[href='/community_rules']", minimum: 1
  end

  test "정책에 동의하지 않은 성인은 온보딩을 완료할 수 없다" do
    [ nil, "0" ].each do |acceptance|
      # 나이와 언어, 마이크는 모두 유효하게 보내 동의 누락만 검증한다.
      # disabled 버튼을 우회해 직접 PATCH를 보내도 서버가 거부해야 한다.
      attributes = {
        native_language_id: languages(:english).id,
        date_of_birth: Date.current.years_ago(20).iso8601,
        microphone_confirmed: "1"
      }
      attributes[:community_rules_accepted] = acceptance unless acceptance.nil?

      patch onboarding_path, params: { user: attributes }

      assert_response :unprocessable_entity
      assert_nil @user.reload.onboarding_completed_at
      assert_nil @user.age_confirmed_at
    end
  end

  test "이용정책은 로그인하지 않아도 읽을 수 있고 금지 행위와 연령 제한을 명시한다" do
    sign_out
    get "/community_rules"

    assert_response :success
    # 실제 안내 페이지의 내용까지 확인한다. 빈 페이지나 개인정보 문서로
    # 대체하면 사용자 콘텐츠의 금지 기준을 전달할 수 없다.
    assert_match "18", response.body
    assert_match /child sexual abuse|child sexual exploitation/i, response.body
    assert_match /harassment/i, response.body
    assert_match /sexual content/i, response.body
    assert_match /report/i, response.body
    assert_match /block/i, response.body
  end
end
