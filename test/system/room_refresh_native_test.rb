require "application_system_test_case"

class RoomRefreshNativeTest < ApplicationSystemTestCase
  test "r_웹의 Refresh 버튼은 iOS와 Android 앱에서는 표시되지 않고 당기기 안내를 유지한다" do
    sign_in(user: users(:english_native))
    visit rooms_path

    # 앱에서 버튼이 없다는 검사만 하면 웹에서도 버튼을 구현하지 않은 채 통과할 수 있다.
    # 같은 화면의 웹 버전에는 버튼이 실제로 존재하는지 먼저 확인한다.
    assert_button "Refresh", disabled: false

    web_user_agent = page.evaluate_script("navigator.userAgent")

    begin
      %w[vtalk/ios/1.0 vtalk/android/1.0].each do |app_user_agent|
        # 화면 너비가 아니라 서버가 실제 사용하는 앱 User-Agent로 앱을 구분한다.
        # 따라서 모바일 웹은 앱으로 오인하지 않고, iOS와 Android 모두 검사한다.
        page.driver.browser.execute_cdp("Network.setUserAgentOverride",
          userAgent: "#{web_user_agent} #{app_user_agent}")

        # Turbo 캐시의 웹 화면을 재사용하지 않도록 실제 페이지를 다시 요청한다.
        page.refresh
        assert_current_path rooms_path
        assert_selector "#room-list"

        # CSS로 버튼만 숨기는 대신 앱에서는 버튼 자체를 렌더링하지 않아야 한다.
        # 앱의 기존 당겨서 새로고침 안내는 그대로 유지한다.
        assert_no_selector "button", text: /Refresh/i, visible: :all
        assert_text "Pull to refresh"
      end
    ensure
      # 다음 테스트가 앱으로 인식되지 않도록 원래 브라우저 User-Agent로 복구한다.
      page.driver.browser.execute_cdp("Network.setUserAgentOverride",
        userAgent: web_user_agent)
    end
  end
end
