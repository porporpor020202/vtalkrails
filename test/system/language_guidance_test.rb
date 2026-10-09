require "application_system_test_case"

class LanguageGuidanceTest < ApplicationSystemTestCase
  test "온보딩과 모국어 설정에 학습 언어 안내가 표시되지 않는다" do
    # 완료한 사용자의 설정 화면과 신규 상태의 온보딩 화면을 각각 확인한다.
    # 선택 상자뿐 아니라 예전 학습 언어 안내 문구도 남아 있으면 안 된다.
    user = users(:english_native)
    sign_in(user: user)
    visit language_setup_path
    assert_no_text "learning language", exact: false
    assert_no_selector "#user_learning_language_id", visible: :all
    user.update!(native_language: nil)
    visit onboarding_path
    assert_current_path onboarding_path
    assert_no_text "learning language", exact: false
    assert_no_selector "#user_learning_language_id", visible: :all
  end
end
