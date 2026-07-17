require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one) # Assumes fixtures exist
  end

  test "should redirect show when not logged in" do
    get settings_url
    assert_redirected_to new_session_url
  end

  test "should get show when logged in" do
    sign_in_as(@user)
    get settings_url
    assert_response :success
  end
end
