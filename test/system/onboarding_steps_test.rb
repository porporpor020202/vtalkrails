require "application_system_test_case"

class OnboardingStepsTest < ApplicationSystemTestCase
  setup do
    load Rails.root.join("db/seeds/languages.rb")
    @user = users(:english_native)
    @user.update!(native_language: nil, age_confirmed_at: nil, onboarding_completed_at: nil)
    sign_in(user: @user)
    visit onboarding_path
  end

  test "choices advance through English onboarding and consent completes the profile" do
    page.driver.browser.manage.window.resize_to(390, 844)
    assert_selector "h1", text: "Select your native language"
    assert_no_button "Sign Out"
    page.save_screenshot("/tmp/vtalk-onboarding-language-after.png")
    fill_in "Search languages", with: "Eng"
    assert_button "English"
    assert_no_button "Korean"
    click_button "English"
    assert_selector '[role="progressbar"][aria-valuenow="2"]'
    page.save_screenshot("/tmp/vtalk-onboarding-age-after.png")
    click_button "Under 18"
    assert_text "You must be at least 18 years old"
    assert_selector "h1", text: "How old are you?"
    click_button "18–24"
    page.save_screenshot("/tmp/vtalk-onboarding-gender-after.png")
    click_button "Prefer not to say"
    page.save_screenshot("/tmp/vtalk-onboarding-microphone-after.png")
    page.execute_script(<<~JS)
      navigator.mediaDevices.getUserMedia = async () => ({ getTracks() { return [{ stop() {} }] } });
    JS
    click_button "Allow microphone"
    assert_selector '[role="progressbar"][aria-valuenow="5"]'
    assert_not @user.reload.onboarding_complete?
    page.save_screenshot("/tmp/vtalk-onboarding-rules-after.png")
    click_button "Agree and start"
    assert_current_path root_path
    assert @user.reload.onboarding_complete?
    assert_equal "18_24", @user.age_group
    assert_equal "undisclosed", @user.gender
    assert_equal languages(:english), @user.native_language
  end

  test "back returns to the previous step and signs out from the first step" do
    click_button "English"
    assert_selector "h1", text: "How old are you?"
    click_button "Back", enable_aria_label: true
    assert_selector "h1", text: "Select your native language"
    click_button "Back", enable_aria_label: true
    assert_current_path new_session_path
    assert_text "You have signed out."
    assert_not @user.reload.onboarding_complete?
  end

  test "denied microphone permission stays on the microphone step" do
    click_button "English"
    click_button "25–34"
    click_button "Female"
    page.execute_script("navigator.mediaDevices.getUserMedia = async () => { throw new DOMException('Denied', 'NotAllowedError') }")
    click_button "Allow microphone"
    assert_text "Microphone access was not allowed."
    assert_selector '[role="progressbar"][aria-valuenow="4"]'
    assert_no_button "Agree and start"
    assert_not @user.reload.onboarding_complete?
  end
end
