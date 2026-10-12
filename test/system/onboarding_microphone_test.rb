require "application_system_test_case"

class OnboardingMicrophoneTest < ApplicationSystemTestCase
  setup do
    @user = users(:english_native)
    @user.update!(native_language: nil)
    sign_in(user: @user)
    click_button "English"
    click_button "18–24"
    click_button "Male"
  end

  test "microphone access is requested only after tapping allow" do
    page.execute_script(<<~JS)
      window.microphoneRequests = 0;
      navigator.mediaDevices.getUserMedia = async () => {
        window.microphoneRequests += 1;
        return { getTracks() { return [{ stop() {} }] } };
      };
    JS
    assert_equal 0, page.evaluate_script("window.microphoneRequests")
    click_button "Allow microphone"
    assert_selector "h1", text: "A space for real conversations"
    assert_equal 1, page.evaluate_script("window.microphoneRequests")
    assert_not @user.reload.onboarding_complete?
  end

  test "a pending permission request cannot complete onboarding" do
    page.execute_script("navigator.mediaDevices.getUserMedia = () => new Promise(resolve => { window.grantMicrophone = resolve })")
    click_button "Allow microphone"
    assert_button "Allow microphone", disabled: true
    assert_text "Waiting for microphone permission"
    assert_no_button "Agree and start"
    assert_not @user.reload.onboarding_complete?
    page.execute_script("window.grantMicrophone({ getTracks() { return [{ stop() {} }] } })")
    assert_button "Agree and start"
  end
end
