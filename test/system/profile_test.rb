require "application_system_test_case"

class ProfileTest < ApplicationSystemTestCase
  test "r_프로필 화면에 내 사진과 디스플레이 이름과 이메일이 표시된다" do
    user = users(:english_native)
    sign_in(user: user)

    visit settings_path
    click_link "Open profile", enable_aria_label: true

    assert_current_path profile_path

    within "main" do
      assert_text user.display_name
      assert_text user.email_address

      image_path = ActionController::Base.helpers.asset_path(
        user.profile_image_path_for
      )
      assert_selector "img[src='#{image_path}']"
    end
  end
end
