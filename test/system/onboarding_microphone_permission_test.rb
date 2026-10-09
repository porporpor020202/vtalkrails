require "application_system_test_case"

class OnboardingMicrophonePermissionTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ] do |options|
    options.add_argument "--mute-audio"
    # 장치만 가짜로 제공하고 권한은 자동 허용하지 않는다.
    options.add_argument "--use-fake-device-for-media-stream"
  end

  setup do
    @user = users(:english_native)
    @user.update!(native_language: nil)
    sign_in(user: @user)
    page.driver.browser.execute_cdp("Browser.resetPermissions")
    assert_current_path onboarding_path
  end

  teardown do
    page.driver.browser.execute_cdp("Browser.resetPermissions")
  end

  test "실제 브라우저 권한을 거부하면 dialog 없이 안내를 유지한다" do
    select_languages_and_age
    set_microphone_permission("denied")
    click_button "Allow microphone"

    # getUserMedia를 교체하지 않고 실제 브라우저의 거부 결과를 검사한다.
    # 닫아야 하는 dialog 대신 다음 행동을 설명하는 텍스트를 유지한다.
    assert_text "Microphone access is denied. Please enable microphone access."
    assert_no_selector "dialog[open]"
    assert_button "Continue", disabled: true
    assert_button "Allow microphone", disabled: false

    # 같은 권한 상태로 재시도해도 안내가 사라지거나 완료되면 안 된다.
    click_button "Allow microphone"
    assert_text "Microphone access is denied. Please enable microphone access."
    assert_button "Continue", disabled: true
    assert_current_path onboarding_path
    assert_nil @user.reload.native_language
    assert_nil @user.attributes["learning_language_id"]
    assert_not @user.onboarding_complete?
  end

  test "설정에서 권한을 허용하고 재시도하면 온보딩을 완료할 수 있다" do
    select_languages_and_age
    set_microphone_permission("denied")
    click_button "Allow microphone"

    assert_text "Microphone access is denied. Please enable microphone access."
    assert_button "Continue", disabled: true

    # 사용자가 설정에서 차단을 해제한 상황을 같은 페이지에서 재현한다.
    set_microphone_permission("granted")
    click_button "Allow microphone"

    assert_text "Microphone access allowed"
    assert_no_text "Microphone access is denied. Please enable microphone access."
    assert_button "Continue", disabled: false

    click_button "Continue"

    assert_current_path root_path, wait: 5
    assert @user.reload.onboarding_complete?
    assert_not_nil @user.age_confirmed_at
    assert_not_nil @user.onboarding_completed_at
  end

  test "허용했던 권한을 브라우저 설정에서 취소하면 Continue를 다시 비활성화한다" do
    select_languages_and_age
    set_microphone_permission("granted")
    click_button "Allow microphone"

    assert_text "Microphone access allowed"
    assert_button "Continue", disabled: false

    # 이전 허용 결과만 기억하면 실제 권한이 없어도 완료할 수 있다.
    # 설정 변경을 감지해 안내와 버튼 상태를 현재 권한에 맞춰 되돌려야 한다.
    set_microphone_permission("denied")

    assert_text "Microphone access is denied. Please enable microphone access."
    assert_button "Continue", disabled: true
    assert_current_path onboarding_path
    assert_not @user.reload.onboarding_complete?
  end

  private

  def select_languages_and_age
    select "Korean", from: "user_native_language_id"
    # 이 테스트의 정상 완료 조건에는 필수 이용정책 동의도 포함한다.
    check "user_community_rules_accepted"
    fill_in "Date of birth", with: Date.current.years_ago(20).iso8601
  end

  def set_microphone_permission(setting)
    page.driver.browser.execute_cdp(
      "Browser.setPermission",
      permission: { name: "microphone" },
      setting: setting,
      origin: page.evaluate_script("location.origin")
    )
  end
end
