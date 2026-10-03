require "remote_origin_test_case"

class DevelopmentBadgeTest < RemoteOriginTestCase
  test "r_개발환경에서는 오른쪽 위에 DEV가 고정 표시된다" do
    visit "https://dev.sayonething.net/session/new"

    assert_selector "span", text: "DEV", exact_text: true
  end
end
