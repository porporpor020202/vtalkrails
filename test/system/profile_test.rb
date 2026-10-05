require "application_system_test_case"

class ProfileTest < ApplicationSystemTestCase
  %i[english_native korean_native].each do |fixture|
    test "r_#{fixture} 사용자의 프로필에 사진과 이름과 이메일과 로그인 제공자가 표시된다" do
      user = users(fixture)
      sign_in(user: user)

      visit settings_path
      click_link "Open profile", enable_aria_label: true

      assert_current_path profile_path

      within "main" do
        assert_text user.display_name
        assert_text user.email_address
        assert_text "Signed in with #{user.oauth_provider.titleize}"

        image_path = ActionController::Base.helpers.asset_path(
          user.profile_image_path_for
        )
        assert_selector "img[src='#{image_path}']"
      end
    end
  end
end
