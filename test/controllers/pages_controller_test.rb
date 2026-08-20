require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "support page is public and provides contact and self-service links" do
    get support_path

    assert_response :success
    assert_select "html[lang='en']"
    assert_select "h1", text: "Support"
    assert_select "a[href^='mailto:privacy@vtalks.net']"
    assert_select "a[href='#{privacy_path}']"
    assert_select "a[href='#{delete_account_path}']"
    assert_select "a[href='#{child_safety_path}']"
  end

  test "privacy policy is public" do
    get privacy_path

    assert_response :success
    assert_select "html[lang='en']"
    assert_select "h1", text: "Privacy Policy"
    assert_select "a[href='mailto:privacy@vtalks.net']"
  end

  test "child safety standards are public and identify the app and reporting contact" do
    get child_safety_path

    assert_response :success
    assert_select "html[lang='en']"
    assert_select "h1", text: "Child Safety Standards"
    assert_select "body", text: /say one thing/
    assert_select "body", text: /Child Sexual Abuse and Exploitation \(CSAE\)/
    assert_select "a[href^='mailto:privacy@vtalks.net']"
  end
end
