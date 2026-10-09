require "test_helper"

class OnboardingAgeBoundaryTest < ActionDispatch::IntegrationTest
  setup do
    # 날짜가 바뀌어도 생일 경계의 의미가 유지되도록 서버 시간을 고정한다.
    # 2026-10-08 기준으로 2008-10-08 출생자는 정확히 만 18세이다.
    travel_to Time.zone.local(2026, 10, 8, 12)
  end

  teardown do
    travel_back
  end

  { google: :korean_native, apple: :english_native }.each do |provider, fixture|
    test "#{provider} 계정은 만 18세 생일 당일부터 서버에서 온보딩을 완료할 수 있다" do
      user = users(fixture)
      assert_equal provider.to_s, user.oauth_provider
      user.update!(age_confirmed_at: nil, onboarding_completed_at: nil)
      sign_in_as(user)

      # 기존 20세 정상 요청 테스트만으로는 최소 나이를 19세나 21세로
      # 올리는 변경을 잡지 못한다. 정확히 18세인 요청이 성공해야 한다.
      # 다른 필수 조건은 모두 충족하여 나이 경계만 검증한다.
      patch onboarding_path, params: { user: {
        native_language_id: languages(:korean).id,
        learning_language_id: languages(:english).id,
        date_of_birth: "2008-10-08",
      # 새 동의 요건도 충족시켜 이 테스트 본래의 나이/안전 동작을 검증한다.
      community_rules_accepted: "1",
      microphone_confirmed: "1"
      } }

      assert_redirected_to root_path
      assert_equal Time.current, user.reload.age_confirmed_at
      assert_equal Time.current, user.onboarding_completed_at
      assert user.onboarding_complete?

      # 저장만 성공하고 실제 앱 접근은 차단하는 경우도 방지한다.
      get rooms_path
      assert_response :success
    end

    test "#{provider} 계정은 만 18세 생일 전날 직접 요청해도 서버에서 거부한다" do
      user = users(fixture)
      assert_equal provider.to_s, user.oauth_provider
      user.update!(age_confirmed_at: nil, onboarding_completed_at: nil)
      sign_in_as(user)

      # 생일이 내일인 사용자는 아직 만 17세이다.
      # disabled 버튼을 우회하여 정상 언어와 마이크 확인을 전송하더라도
      # 클라이언트가 아닌 서버가 18세 미만임을 판정해야 한다.
      patch onboarding_path, params: { user: {
        native_language_id: languages(:korean).id,
        learning_language_id: languages(:english).id,
        date_of_birth: "2008-10-09",
      # 새 동의 요건도 충족시켜 이 테스트 본래의 나이/안전 동작을 검증한다.
      community_rules_accepted: "1",
      microphone_confirmed: "1"
      } }

      assert_response :unprocessable_entity
      assert_nil user.reload.age_confirmed_at
      assert_nil user.onboarding_completed_at
      assert_not user.onboarding_complete?

      # 실패 응답만 보내면서 완료 상태를 저장하는 구현을 방지한다.
      # 이후 보호된 화면에 직접 접근해도 온보딩으로 돌아가야 한다.
      get rooms_path
      assert_redirected_to onboarding_path
    end
  end
end
