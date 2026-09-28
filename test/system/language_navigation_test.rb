require "application_system_test_case"

class LanguageNavigationSystemTest < ApplicationSystemTestCase
  test "onboarding requires different languages and tabs have independent active states" do
    user = users(:english_speaker)
    user.update!(mother_language: nil, learning_language: nil)
    token = user.signed_id(purpose: :native_auth, expires_in: 5.minutes)
    visit authenticate_by_token_google_oauth_sessions_path(token: token)
    assert_current_path language_setup_path
    assert_button "Continue", disabled: true
    select "Korean", from: "Mother Language"
    assert_selector "#user_learning_language_id option[disabled]", text: "Korean", visible: :all
    select "English", from: "Learning Language"
    assert_button "Continue", disabled: false
    click_button "Continue"
    assert_current_path rooms_path(tab: "learning")
    within "#bottom-tab-bar" do
      assert_selector "a[aria-current='page']", count: 1, text: "Learning Language"
      click_link "Mother Language"
      assert_selector "a[aria-current='page']", count: 1, text: "Mother Language"
      click_link "Setting"
      assert_selector "a[aria-current='page']", count: 1, text: "Setting"
    end
    select "English", from: "Mother Language"
    assert_select "Learning Language", selected: "Select language"
    assert_button "Save", disabled: true
    select "Korean", from: "Learning Language"
    click_button "Save"
    assert_text "Language settings saved."
  end
end
