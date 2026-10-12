require "application_system_test_case"

class OnboardingHistoryTest < ApplicationSystemTestCase
  test "신규 사용자가 온보딩을 완료하면 뒤로가도 온보딩과 로그인 화면이 표시되지 않는다" do
    user = User.create!(
      oauth_provider: "google",
      oauth_uid: SecureRandom.uuid,
      email_address: "new-user@example.com"
    )

    visit new_session_path
    assert_text "Continue with Google"

    sign_in(user: user)
    assert_current_path onboarding_path

    click_button "English"
    click_button "18–24"
    click_button "Prefer not to say"
    # 이 테스트의 정상 완료 조건에는 필수 이용정책 동의도 포함한다.


    assert_no_button "Agree and start"

    page.execute_script(<<~JS)
      navigator.mediaDevices.getUserMedia = async () => ({
        getTracks() {
          return [{ stop() {} }];
        }
      });
    JS

    # 생년월일로 18세 이상임을 확인한 후 온보딩을 완료한다.


    click_button "Allow microphone"

    assert_text "A space for real conversations"
    assert_button "Agree and start", disabled: false
    click_button "Agree and start"

    assert_current_path root_path
    assert_button "Drop a voice"
    assert user.reload.onboarding_complete?

    2.times do
      page.go_back

      assert_current_path root_path
      assert_button "Drop a voice"

      assert_no_selector "form[action='#{onboarding_path}']"
      assert_no_text "Continue with Google"
      assert_no_text "Continue with Apple"
    end
  end
end
