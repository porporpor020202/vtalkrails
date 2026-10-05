require "application_system_test_case"

class OnboardingHistoryTest < ApplicationSystemTestCase
  test "r_신규 사용자가 온보딩을 완료하면 뒤로가도 온보딩과 로그인 화면이 표시되지 않는다" do
    user = User.create!(
      oauth_provider: "google",
      oauth_uid: SecureRandom.uuid,
      email_address: "new-user@example.com"
    )

    visit new_session_path
    assert_text "Continue with Google"

    sign_in(user: user)
    assert_current_path onboarding_path

    select "English", from: "user_native_language_id"
    select "Korean", from: "user_learning_language_id"
    click_button "Continue"

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
