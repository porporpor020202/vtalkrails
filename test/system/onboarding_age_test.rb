require "application_system_test_case"

class OnboardingAgeTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ] do |options|
    options.add_argument "--mute-audio"
    options.add_argument "--use-fake-device-for-media-stream"
  end

  setup do
    @user = users(:english_native)
    @user.update!(native_language: nil, learning_language: nil)
    sign_in(user: @user)
    page.driver.browser.execute_cdp("Browser.resetPermissions")
    assert_current_path onboarding_path
  end

  teardown do
    page.driver.browser.execute_cdp("Browser.resetPermissions")
  end

  test "r_초기 화면에서 완료에 필요한 항목을 안내한다" do
    assert_text "Please select your native language."
    assert_text "Please select your learning language."
    assert_text "Microphone access is denied. Please enable microphone access."
    assert_text "Please enter your date of birth."
    assert_field "Date of birth", with: ""
    assert_button "Allow microphone", disabled: false
    assert_button "Continue", disabled: true
  end

  test "r_학습 언어와 관계없이 모든 신규 사용자에게 나이 확인을 요구한다" do
    # 영어 학습자를 해외 사용자로 간주하지 않는다.
    # 어떤 언어 조합을 선택해도 나이 확인 입력란은 유지되어야 한다.
    language_pairs = [ [ "Korean", "English" ], [ "English", "Korean" ] ]

    language_pairs.each do |native, learning|
      select native, from: "user_native_language_id"
      select learning, from: "user_learning_language_id"

      assert_field "Date of birth", with: ""
      assert_text "Please enter your date of birth."
      assert_button "Continue", disabled: true
    end
  end

  test "r_언어와 마이크를 준비해도 나이를 입력하지 않으면 완료할 수 없다" do
    prepare_languages_and_microphone

    assert_text "Please enter your date of birth."
    assert_button "Continue", disabled: true
    assert_current_path onboarding_path
    assert_not @user.reload.onboarding_complete?
  end

  test "r_18세 생일 전날인 사용자는 완료할 수 없다" do
    prepare_languages_and_microphone

    # 오늘보다 생일이 하루 늦으므로 아직 만 17세이다.
    fill_in "Date of birth", with: (Date.current.years_ago(18) + 1.day).iso8601

    assert_text "You must be at least 18 years old."
    assert_button "Continue", disabled: true
    assert_not @user.reload.onboarding_complete?
  end

  test "r_미래 생년월일을 입력하면 올바른 날짜를 입력하도록 안내한다" do
    prepare_languages_and_microphone
    fill_in "Date of birth", with: Date.tomorrow.iso8601

    assert_text "Please enter a valid date of birth."
    assert_button "Continue", disabled: true
    assert_not @user.reload.onboarding_complete?
  end

  test "r_18세 생일 당일부터 Continue로 저장하고 루트로 이동할 수 있다" do
    prepare_languages_and_microphone
    fill_in "Date of birth", with: Date.current.years_ago(18).iso8601

    assert_button "Continue", disabled: false
    assert_current_path onboarding_path
    assert_nil @user.reload.native_language
    assert_nil @user.learning_language
    assert_not @user.onboarding_complete?

    # 나이 확인을 포함한 완료는 Continue를 누를 때만 저장한다.
    assert_no_difference "User.count" do
      click_button "Continue"
      assert_current_path root_path, wait: 5
    end

    assert_equal languages(:korean), @user.reload.native_language
    assert_equal languages(:english), @user.learning_language
    assert_not_nil @user.age_confirmed_at
    assert_not_nil @user.onboarding_completed_at
    assert @user.onboarding_complete?
  end

  test "r_나이를 입력했다가 지우면 안내와 Continue 비활성 상태로 돌아온다" do
    prepare_languages_and_microphone
    fill_in "Date of birth", with: Date.current.years_ago(20).iso8601
    assert_button "Continue", disabled: false

    fill_in "Date of birth", with: ""

    assert_text "Please enter your date of birth."
    assert_button "Continue", disabled: true
    assert_not @user.reload.onboarding_complete?
  end

  test "r_완료 후 재로그인해도 나이를 다시 묻지 않는다" do
    prepare_languages_and_microphone
    fill_in "Date of birth", with: Date.current.years_ago(20).iso8601
    click_button "Continue"
    assert_current_path root_path, wait: 5

    confirmed_at = @user.reload.age_confirmed_at
    assert_not_nil confirmed_at

    Capybara.reset_sessions!
    sign_in(user: @user)

    assert_current_path root_path, wait: 5
    assert_equal confirmed_at, @user.reload.age_confirmed_at

    visit onboarding_path
    assert_current_path root_path, wait: 5
  end

  test "r_온보딩 생년월일에 숫자만 입력하면 대시가 자동으로 삽입된다" do
    # 기존 온보딩 완료 정보를 초기화하여 실제 생년월일 입력 화면에 진입한다.
    user = users(:english_native)
    user.update!(native_language: nil, learning_language: nil)
    sign_in(user: user)
    assert_current_path onboarding_path

    birthday = find_field("Date of birth")

    # fill_in 대신 키 입력을 사용하여 사용자가 숫자를 순서대로 타이핑하는
    # 상황과 각 입력마다 실행되는 자동 서식 처리를 검증한다.
    birthday.send_keys("1998")
    assert_field "Date of birth", with: "1998"

    # 월을 입력하면 연도와 월 사이에 대시가 자동으로 들어가야 한다.
    birthday.send_keys("01")
    assert_field "Date of birth", with: "1998-01"

    # 일을 입력하면 두 번째 대시도 들어가서 YYYY-MM-DD 형식이 완성된다.
    birthday.send_keys("23")
    assert_field "Date of birth", with: "1998-01-23"

    # 생년월일만 입력해도 다른 필수 조건을 건너뛰어 완료할 수는 없다.
    assert_button "Continue", disabled: true
    assert_current_path onboarding_path
  end

  private

  def prepare_languages_and_microphone
    select "Korean", from: "user_native_language_id"
    select "English", from: "user_learning_language_id"
    page.driver.browser.execute_cdp(
      "Browser.setPermission",
      permission: { name: "microphone" },
      setting: "granted",
      origin: page.evaluate_script("location.origin")
    )
    click_button "Allow microphone"
    assert_text "Microphone access allowed"
  end
end
