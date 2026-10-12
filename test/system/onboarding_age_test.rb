require "application_system_test_case"

class OnboardingAgeTest < ApplicationSystemTestCase
  setup do
    @user = users(:english_native)
    @user.update!(native_language: nil)
    sign_in(user: @user)
    click_button "English"
  end

  test "under 18 stays on the age screen without completing onboarding" do
    click_button "Under 18"
    assert_text "You must be at least 18 years old"
    assert_selector '[role="progressbar"][aria-valuenow="2"]'
    assert_nil @user.reload.age_confirmed_at
    assert_not @user.onboarding_complete?
  end

  test "every adult age group advances immediately without saving" do
    ["18–24", "25–34", "35–44", "45+"].each do |label|
      click_button label
      assert_selector "h1", text: "What is your gender?"
      assert_nil @user.reload.age_group
      assert_nil @user.age_confirmed_at
      click_button "Back", enable_aria_label: true
    end
  end
end
