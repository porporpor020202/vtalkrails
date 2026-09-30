require "application_system_test_case"

class LanguageNavigationSystemTest < ApplicationSystemTestCase
  test "native language onboarding leads to Say and two navigation tabs" do
    user = users(:korean_native)
    user.update!(native_language: nil)
    visit authenticate_by_token_google_oauth_sessions_path(token: user.signed_id(purpose: :native_auth, expires_in: 5.minutes))
    assert_current_path language_setup_path
    assert_selector "select", count: 1
    select "English", from: "Native language"
    click_button "Continue"
    assert_current_path rooms_path
    assert_text "Say one thing in English."
    within "#bottom-tab-bar" do
      assert_selector "a", count: 2
      assert_selector "a[aria-current='page']", count: 1, text: "Say"
      click_link "Setting"
      assert_selector "a[aria-current='page']", count: 1, text: "Setting"
    end
    select "Korean", from: "Native language"
    click_button "Save"
    assert_text "Language settings saved."
    assert_equal languages(:korean), user.reload.native_language
  end
end
