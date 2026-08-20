require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "privacy policy is public" do
    get privacy_path

    assert_response :success
    assert_select "html[lang='en']"
    assert_select "h1", text: "Privacy Policy"
    assert_select "a[href='mailto:privacy@vtalks.net']"
  end
end
