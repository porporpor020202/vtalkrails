require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  test "signed in user can access child safety reporting and standards" do
    sign_in_as users(:one)

    get settings_path

    assert_response :success
    assert_select "a[href^='mailto:privacy@vtalks.net']", text: /Report a child safety concern/
    assert_select "a[href='#{child_safety_path}']", text: /Child Safety Standards/
  end
end
