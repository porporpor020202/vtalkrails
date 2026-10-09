require "application_system_test_case"

class OnboardingMicrophoneTest < ApplicationSystemTestCase
  setup do
    @user = users(:english_native)
    @user.update!(native_language: nil)

    sign_in(user: @user)
    assert_current_path onboarding_path

    page.execute_script("sessionStorage.removeItem('onboarding_microphone_stopped')")
  end

  test "모국어와 마이크와 나이와 이용정책 동의를 모두 확인해야 Continue가 활성화된다" do
    # 필수 동의를 포함한 네 조건의 16가지 조합을 검사한다. 이전 화면에서 확인한 마이크 상태가
    # 다음 조합으로 이어지지 않도록 매번 온보딩 페이지를 새로 방문한다.
    conditions = [ false, true ].repeated_permutation(4).to_a

    conditions.each do |native, microphone, adult, rules|
      visit onboarding_path
      assert_continue_disabled

      select "Korean", from: "user_native_language_id" if native
      fill_in "Date of birth", with: Date.current.years_ago(20).iso8601 if adult
      # 동의는 기본 선택이 아니며 사용자가 직접 체크해야 한다.
      assert_unchecked_field "user_community_rules_accepted"
      check "user_community_rules_accepted" if rules

      if microphone
        allow_microphone
        click_button "Allow microphone"
        assert_text "Microphone access allowed"
      end

      # 완료한 항목의 안내는 사라지고, 아직 필요한 항목은 계속 안내한다.
      if native
        assert_no_text "Please select your native language."
      else
        assert_text "Please select your native language."
      end

      if microphone
        assert_no_text "Microphone access is denied. Please enable microphone access."
      else
        assert_text "Microphone access is denied. Please enable microphone access."
      end

      if adult
        assert_no_text "Please enter your date of birth."
      else
        assert_text "Please enter your date of birth."
      end

      context = "native=#{native}, microphone=#{microphone}, adult=#{adult}, rules=#{rules}"
      assert_equal !(native && microphone && adult && rules), find_button("Continue", disabled: :all).disabled?, context

      if native && microphone && adult && rules
        assert_continue_enabled
      else
        assert_continue_disabled
      end

      # 조건을 모두 채웠더라도 Continue를 누르기 전에는 저장하지 않는다.
      assert_current_path onboarding_path
      assert_onboarding_not_saved
    end
  end

  test "마이크 권한을 허용하면 확인용 마이크를 해제하고 Continue로 온보딩을 완료한다" do
    select_native_language_and_accept_rules
    fill_in "Date of birth", with: Date.current.years_ago(20).iso8601
    allow_microphone

    click_button "Allow microphone"
    assert_text "Microphone access allowed"
    assert_continue_enabled

    # 나머지 조건이 준비되어도 동의를 취소하면 완료할 수 없어야 한다.
    uncheck "user_community_rules_accepted"
    assert_continue_disabled
    assert_onboarding_not_saved
    check "user_community_rules_accepted"
    assert_continue_enabled

    assert_equal "true", page.evaluate_script("sessionStorage.getItem('onboarding_microphone_stopped')")
    assert_onboarding_not_saved

    assert_no_difference "User.count" do
      click_button "Continue"
      assert_current_path root_path, wait: 5
    end

    assert_equal languages(:korean), @user.reload.native_language
    assert_nil @user.attributes["learning_language_id"]
    assert_not_nil @user.display_name
    assert @user.onboarding_complete?
    assert_not_nil @user.age_confirmed_at
    assert_not_nil @user.onboarding_completed_at
  end

  test "마이크 권한이 없으면 안내 문구를 계속 표시하고 Continue를 비활성 상태로 유지한다" do
    select_native_language_and_accept_rules
    fill_in "Date of birth", with: Date.current.years_ago(20).iso8601
    deny_microphone

    assert_button "Allow microphone", disabled: false
    assert_text "Microphone access is denied. Please enable microphone access."
    assert_continue_disabled
    assert_current_path onboarding_path
    assert_onboarding_not_saved
  end

  test "마이크 권한 요청이 응답을 기다리는 동안 Continue는 비활성 상태이다" do
    select_native_language_and_accept_rules
    fill_in "Date of birth", with: Date.current.years_ago(20).iso8601

    # 허용과 거부 어느 쪽으로도 끝나지 않는 요청을 만든다.
    # 요청이 시작된 사실을 먼저 확인해 초기 비활성 상태만 검사하지 않는다.
    page.execute_script(<<~JS)
      window.onboardingMicrophoneRequested = false;
      navigator.mediaDevices.getUserMedia = () => {
        window.onboardingMicrophoneRequested = true;
        return new Promise(() => {});
      };
    JS

    click_button "Allow microphone"

    assert page.evaluate_script("window.onboardingMicrophoneRequested")
    assert_continue_disabled
    assert_current_path onboarding_path
    assert_onboarding_not_saved
  end

  test "네 조건 완료 후 모국어를 변경해도 Continue는 활성 상태를 유지한다" do
    # 모국어 변경은 더 이상 학습 언어 초기화를 유발하지 않는다.
    select_native_language_and_accept_rules
    fill_in "Date of birth", with: Date.current.years_ago(20).iso8601
    allow_microphone
    click_button "Allow microphone"
    assert_continue_enabled
    select "English", from: "user_native_language_id"
    assert_continue_enabled
    assert_onboarding_not_saved
  end

  private

  def select_native_language_and_accept_rules
    select "Korean", from: "user_native_language_id"
    # 마이크 테스트에서는 다른 필수 조건인 이용정책 동의를 미리 완료한다.
    check "user_community_rules_accepted"
  end

  def assert_continue_disabled
    assert_button "Continue", disabled: true
    find_button("Continue", disabled: true).assert_matches_style opacity: "0.5"
  end

  def assert_continue_enabled
    assert_button "Continue", disabled: false
    find_button("Continue", disabled: false).assert_matches_style opacity: "1"
  end

  def allow_microphone
    page.execute_script(<<~JS)
      navigator.mediaDevices.getUserMedia = async (constraints) => {
        if (constraints.audio !== true) {
          throw new Error("Microphone access must be requested.");
        }

        return {
          getTracks() {
            return [{
              stop() {
                sessionStorage.setItem("onboarding_microphone_stopped", "true");
              }
            }];
          }
        };
      };
    JS
  end

  def deny_microphone
    page.execute_script(<<~JS)
      navigator.mediaDevices.getUserMedia = async () => {
        throw new DOMException("Permission denied", "NotAllowedError");
      };
    JS
  end

  def assert_onboarding_not_saved
    @user.reload
    assert_nil @user.native_language
    assert_nil @user.attributes["learning_language_id"]
    assert_not @user.onboarding_complete?
    assert_nil @user.age_confirmed_at
    assert_nil @user.onboarding_completed_at
  end
end
