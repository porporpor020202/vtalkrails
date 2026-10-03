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

  test "r_온보딩에서 모국어를 선택할 수 있다" do
    select "Korean", from: "user_native_language"

    assert_select "user_native_language", selected: "Korean"
  end

  test "r_모국어를 선택하지 않고 Continue를 누르면 입력 오류를 표시한다" do
    click_button "Continue"

    field = find("#user_native_language")
    assert field.evaluate_script("this.validity.valueMissing")
    assert field.evaluate_script("this.matches(':invalid')")
    assert field.evaluate_script("this === document.activeElement")
    assert field.evaluate_script("this.validationMessage.length > 0")

    assert_current_path onboarding_path
    assert_nil @user.reload.native_language
  end

  test "r_모국어를 선택하고 Continue를 누르면 저장하고 홈으로 이동한다" do
    assert_no_difference "User.count" do
      select "Korean", from: "user_native_language"
      click_button "Continue"

      assert_current_path root_path, wait: 5
    end

    @user.reload
    assert_equal "Korean", @user.native_language
    assert_not_nil @user.display_name
    assert @user.onboarding_complete?
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
      assert_selector "#user_native_language"

      assert_equal 1, generated_names.size
      assert generated_names.first.present?
      assert_equal generated_names.first, @user.reload.display_name
    end
  end
end
