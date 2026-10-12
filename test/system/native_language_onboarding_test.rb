require "application_system_test_case"

class NativeLanguageOnboardingTest < ApplicationSystemTestCase
  test "enabled native languages advance while disabled languages are absent" do
    user = users(:english_native)
    user.update!(native_language: nil)
    sign_in(user: user)
    Language.enabled.each do |language|
      click_button language.label
      assert_selector "h1", text: "How old are you?"
      assert_equal language.id.to_s, find("#user_native_language_id", visible: :all).value
      assert_nil user.reload.native_language
      click_button "Back", enable_aria_label: true
    end
    Language.where(enable: false).each { |language| assert_no_button language.label }
  end
end
