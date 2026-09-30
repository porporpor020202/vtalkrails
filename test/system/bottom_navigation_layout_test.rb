require "application_system_test_case"

class BottomNavigationLayoutTest < ApplicationSystemTestCase
  test "바텀 네비게이션이 viewport 하단에 고정된다" do
    token = users(:korean_native).signed_id(purpose: :native_auth, expires_in: 5.minutes)
    visit authenticate_by_token_google_oauth_sessions_path(token: token)
    assert_current_path root_path

    assert_bottom_navigation_fixed

    click_link "Setting"
    assert_current_path settings_path
    assert_bottom_navigation_fixed
  end

  private

  def assert_bottom_navigation_fixed
    assert_selector "#bottom-tab-bar"

    metrics = page.evaluate_script(<<~JAVASCRIPT)
      (() => {
        const nav = document.querySelector("#bottom-tab-bar");
        const style = getComputedStyle(nav);
        const rect = nav.getBoundingClientRect();

        return {
          position: style.position,
          bottom: style.bottom,
          viewportBottom: window.innerHeight - rect.bottom
        };
      })()
    JAVASCRIPT

    assert_equal "fixed", metrics.fetch("position")
    assert_equal "0px", metrics.fetch("bottom")
    assert_in_delta 0.0, metrics.fetch("viewportBottom").to_f, 1.0
  end
end
