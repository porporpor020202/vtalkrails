require "application_system_test_case"

class LanguageGuidanceTest < ApplicationSystemTestCase
  test "r_온보딩과 언어 변경 세팅 화면에 마더랭기쥐와 러닝랭기지가 같을 수 없다는 안내가 표시된다" do
    user = users(:english_native)
    sign_in(user: user)

    message = "Your native language and learning language cannot be the same."

    visit language_setup_path

    within "main" do
      assert_text message
    end

    # 언어 설정을 비워 온보딩이 필요한 상태로 만든다.
    user.update!(native_language: nil, learning_language: nil)

    visit onboarding_path

    assert_current_path onboarding_path

    within "main" do
      assert_text message
    end
  end
end
