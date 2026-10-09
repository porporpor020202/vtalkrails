require "application_system_test_case"
require "minitest/mock"

class OnboardingTest < ApplicationSystemTestCase
  setup do
    @previous_session_name = Capybara.session_name
    Capybara.session_name = :local_onboarding
    Current.reset

    @user = users(:english_native)
    @user.update!(display_name: nil)
    @user.update!(native_language: nil)

    @sign_in_session_id = sign_in(user: @user).id
    assert_current_path onboarding_path, wait: 5
  end

  teardown do
    Capybara.current_session.reset!
    Capybara.session_name = @previous_session_name
    Current.reset
  end

  test "온보딩에서 모국어를 선택할 수 있다" do
    select "Korean", from: "user_native_language_id"

    assert_select "user_native_language_id", selected: "Korean"
  end

  test "온보딩에는 학습 언어 입력이 없다" do
    # 모국어만 선택하며 학습 언어 선택은 숨겨진 입력으로도 제출하지 않는다.
    assert_no_selector "[name='user[learning_language_id]']", visible: :all
    assert_no_text "learning language", exact: false
  end

  test "온보딩을 완료한 사용자가 온보딩 페이지에 접속하면 root_path로 이동한다" do
    # 언어만 저장된 사용자를 완료 상태로 간주하지 않는다.
    # 이 테스트는 나이 확인과 명시적인 완료 기록까지 저장된 사용자를 준비한다.
    @user.update!(display_name: "Bright Panda", native_language: languages(:english), age_confirmed_at: Time.current, onboarding_completed_at: Time.current)
    assert @user.onboarding_complete?

    visit onboarding_path
    assert @user.onboarding_complete?

    assert_current_path root_path, wait: 5
  end

  test "온보딩에서 Sign Out을 누르면 로그아웃된다" do
    click_button "Sign Out"

    assert_current_path new_session_path, wait: 5
    assert_text "You have signed out."
    assert_not Session.exists?(@sign_in_session_id)

    visit onboarding_path

    assert_current_path new_session_path, wait: 5
    assert_nil @user.reload.native_language
  end

  test "온보딩에 접속하면 생성기로 닉네임을 생성하고 저장한다" do
    @user.reload.update!(display_name: nil)

    generator = UserDisplayNameGenerator.method(:display_name)
    generated_names = []

    tracked_generator = lambda do
      generator.call.tap { |name| generated_names << name }
    end

    UserDisplayNameGenerator.stub(:display_name, tracked_generator) do
      visit onboarding_path

      assert_current_path onboarding_path
      assert_selector "#user_native_language_id"

      assert_equal 1, generated_names.size
      assert generated_names.first.present?
      assert_equal generated_names.first, @user.reload.display_name
    end
  end
end
