require "application_system_test_case"

class NativeLanguageOnboardingTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ] do |options|
    # 실제 녹음 장치 대신 Chrome의 테스트 장치를 사용한다.
    # 마이크 버튼을 누르면 실제 getUserMedia 호출이 성공하도록 권한도 허용한다.
    options.add_argument "--mute-audio"
    options.add_argument "--use-fake-device-for-media-stream"
    options.add_argument "--use-fake-ui-for-media-stream"
  end

  setup do
    # 학습 언어가 한 번도 설정되지 않은 신규 사용자로 시작한다.
    @user = User.create!(oauth_provider: "google", oauth_uid: SecureRandom.uuid,
                         email_address: "native-onboarding@example.com")
    sign_in(user: @user)
    assert_current_path onboarding_path
  end

  [ :english, :korean ].each do |language|
    test "모국어가 #{language}인 신규 사용자는 학습 언어 없이 온보딩을 완료한다" do
      # 영어 원어민도 영어 대화 앱을 사용할 수 있다.
      # 모국어가 English라고 해서 다른 학습 언어를 요구하거나 저장을 막으면 안 된다.
      assert_no_selector "#user_learning_language_id", visible: :all
      assert_no_selector "[name='user[learning_language_id]']", visible: :all
      assert_no_text "learning language", exact: false

      select languages(language).label, from: "user_native_language_id"
      fill_in "Date of birth", with: Date.current.years_ago(20).iso8601
      check "user_community_rules_accepted"
      # 언어 선택을 줄여도 기존 필수 마이크 확인 조건은 유지한다.
      assert_button "Continue", disabled: true
      click_button "Allow microphone"
      assert_text "Microphone access allowed"
      assert_button "Continue", disabled: false
      click_button "Continue"

      assert_current_path root_path
      assert_button "Drop a voice"
      assert_equal languages(language), @user.reload.native_language
      # 학습 언어를 English로 자동 설정하는 우회 구현도 허용하지 않는다.
      assert_nil @user.attributes["learning_language_id"]
      assert_not_nil @user.age_confirmed_at
      assert_not_nil @user.onboarding_completed_at
      assert @user.onboarding_complete?

      # 새 요청에서도 완료 상태로 판단해야 한다. 저장 직후 이동만 성공해서는 안 된다.
      visit onboarding_path
      assert_current_path root_path
      assert_button "Drop a voice"
    end
  end

  test "학습 언어가 없어도 모국어 나이 마이크 이용정책 동의는 모두 필수다" do
    # 다른 조건을 충족해도 모국어가 없으면 완료할 수 없다.
    fill_in "Date of birth", with: Date.current.years_ago(20).iso8601
    check "user_community_rules_accepted"
    click_button "Allow microphone"
    assert_text "Microphone access allowed"
    assert_button "Continue", disabled: true
    assert_text "Please select your native language."

    select "Korean", from: "user_native_language_id"
    assert_button "Continue", disabled: false

    # 이용정책 동의를 취소하거나 미성년 생년월일을 입력하면 다시 완료를 막는다.
    uncheck "user_community_rules_accepted"
    assert_button "Continue", disabled: true
    check "user_community_rules_accepted"
    fill_in "Date of birth", with: Date.current.years_ago(17).iso8601
    assert_button "Continue", disabled: true
    assert_text "You must be at least 18 years old."
    assert_current_path onboarding_path
    assert_not @user.reload.onboarding_complete?
    assert_nil @user.onboarding_completed_at
  end
end
