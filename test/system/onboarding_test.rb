require "application_system_test_case"
require "minitest/mock"

class OnboardingTest < ApplicationSystemTestCase
  setup do
    @previous_session_name = Capybara.session_name
    Capybara.session_name = :local_onboarding
    Current.reset

    @user = users(:english_native)
    @user.update!(display_name: nil)
    @user.update!(native_language: nil, learning_language: nil)

    @sign_in_session_id = sign_in(user: @user).id
    assert_current_path onboarding_path, wait: 5
  end

  teardown do
    Capybara.current_session.reset!
    Capybara.session_name = @previous_session_name
    Current.reset
  end

  test "r_온보딩에서 모국어를 선택할 수 있다" do
    select "Korean", from: "user_native_language_id"

    assert_select "user_native_language_id", selected: "Korean"
  end

  test "r_온보딩에서 학습할 언어를 선택할 수 있다" do
    select "Korean", from: "user_native_language_id"
    select "English", from: "user_learning_language_id"

    assert_select "user_learning_language_id", selected: "English"
    assert_select "user_native_language_id", selected: "Korean"
  end

  test "r_온보딩에서 모국어와 같은 언어를 학습 언어로 선택할 수 없다" do
    select "Korean", from: "user_native_language_id"

    assert_selector "#user_learning_language_id"
    assert find("#user_learning_language_id option", text: "Korean").disabled?

    select "English", from: "user_learning_language_id"

    assert_select "user_learning_language_id", selected: "English"
    assert_select "user_native_language_id", selected: "Korean"
  end

  test "r_모국어를 학습 언어로 변경하면 학습 언어 선택을 초기화한다" do
    select "Korean", from: "user_native_language_id"
    select "English", from: "user_learning_language_id"
    select "English", from: "user_native_language_id"

    assert_select "user_learning_language_id", selected: "Select your learning language"
    assert find("#user_learning_language_id option", text: "English").disabled?

    select "Korean", from: "user_learning_language_id"
    assert_select "user_learning_language_id", selected: "Korean"
  end

  test "r_온보딩을 완료한 사용자가 온보딩 페이지에 접속하면 root_path로 이동한다" do
    # 언어만 저장된 사용자를 완료 상태로 간주하지 않는다.
    # 이 테스트는 나이 확인과 명시적인 완료 기록까지 저장된 사용자를 준비한다.
    @user.update!(display_name: "Bright Panda", native_language: languages(:english), learning_language: languages(:korean), age_confirmed_at: Time.current, onboarding_completed_at: Time.current)
    assert @user.onboarding_complete?

    visit onboarding_path
    assert @user.onboarding_complete?

    assert_current_path root_path, wait: 5
  end

  test "r_온보딩에서 Sign Out을 누르면 로그아웃된다" do
    click_button "Sign Out"

    assert_current_path new_session_path, wait: 5
    assert_text "You have signed out."
    assert_not Session.exists?(@sign_in_session_id)

    visit onboarding_path

    assert_current_path new_session_path, wait: 5
    assert_nil @user.reload.native_language
  end

  test "r_온보딩에 접속하면 생성기로 닉네임을 생성하고 저장한다" do
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
