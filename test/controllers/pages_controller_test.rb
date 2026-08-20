require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "privacy policy is public" do
    get privacy_path

    assert_response :success
    assert_select "html[lang='ko']"
    assert_select "h1", text: "개인정보처리방침"
    assert_select "a[href='mailto:privacy@vtalks.net']"
  end
end
