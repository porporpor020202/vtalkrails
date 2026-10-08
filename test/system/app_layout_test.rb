require "application_system_test_case"

class AppLayoutTest < ApplicationSystemTestCase
  teardown do
    # 모바일 화면 에뮬레이션도 해제하여 다음 데스크톱 테스트와 격리한다.
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    # 다음 테스트에 좁은 창 너비가 영향을 주지 않도록 기본 크기로 돌아간다.
    page.current_window.resize_to(1400, 1000)
  end

  %i[login say settings].each do |screen|
    test "r_#{screen} 화면은 데스크톱에서 중앙의 430px 앱 영역 안에 표시된다" do
      # 로그인 전후의 서로 다른 화면이 같은 공통 앱 컨테이너를 사용하는지 확인한다.
      # CSS 클래스 문자열 대신 실제 브라우저가 계산한 크기와 위치를 검사한다.
      visit_screen(screen)
      assert_selector "#app-shell"

      shell = bounds("#app-shell")
      viewport_width = page.evaluate_script("window.innerWidth")
      assert_in_delta 430, shell.fetch("width"), 1
      assert_in_delta (viewport_width - 430) / 2.0, shell.fetch("left"), 1

      # 본문과 하단 탭까지 앱 영역 안에 있어야 한다.
      # 본문만 좁히고 네비게이션을 브라우저 전체에 펼치는 구현을 방지한다.
      assert_inside_shell("main")
      assert_inside_shell("#bottom-tab-bar") unless screen == :login

      # 로그인 배경이 브라우저 전체에 전파되지 않도록 바깥 배경을 구분한다.
      # 바깥 배경은 html 또는 body에 둘 수 있으므로 실제 색이 지정된 쪽을 사용한다.
      colors = page.evaluate_script(<<~JS)
        (() => {
          const html = getComputedStyle(document.documentElement).backgroundColor;
          const body = getComputedStyle(document.body).backgroundColor;
          const outer = html === "rgba(0, 0, 0, 0)" ? body : html;
          return { outer, inner: getComputedStyle(document.querySelector("#app-shell")).backgroundColor };
        })()
      JS
      refute_equal "rgba(0, 0, 0, 0)", colors.fetch("inner"), "앱 영역에는 자체 배경색이 필요하다."
      refute_equal colors.fetch("outer"), colors.fetch("inner"), "앱 바깥 여백과 앱 배경이 구분되어야 한다."
    end

    test "#{screen} 화면은 모바일에서 화면 폭을 채우고 가로 스크롤이 없다" do
      # 데스크톱 폭을 고정값으로만 지정해 좁은 모바일 화면이 잘리는 것을 방지한다.
      page.current_window.resize_to(375, 812)
      # Chrome 창은 최소 너비가 500px이므로 창 크기 변경만으로 모바일을 재현할 수 없다.
      # 실제 페이지 viewport를 375px로 지정해 모바일 레이아웃을 검증한다.
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
        width: 375, height: 812, deviceScaleFactor: 1, mobile: true)
      visit_screen(screen)
      assert_selector "#app-shell"

      shell = bounds("#app-shell")
      viewport_width = page.evaluate_script("window.innerWidth")
      assert_in_delta viewport_width, shell.fetch("width"), 1
      assert_in_delta 0, shell.fetch("left"), 1
      assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, viewport_width
    end
  end

  test "Say의 고정 버튼과 녹음 창도 공통 앱 영역 안에 표시된다" do
    visit_screen(:say)
    assert_selector "#app-shell"

    # 실제 화면에서 고정 버튼의 위치를 확인한 후 녹음 창을 연다.
    # fixed 요소는 부모의 max-width만으로 제한되지 않으므로 별도 회귀 검사가 필요하다.
    assert_inside_shell('[data-action="voice-recorder#openSheet"]')
    assert_inside_shell('button[aria-label="Receive new rooms"]')
    click_button "Drop a voice"
    assert_selector '[data-voice-recorder-target="sheet"]', visible: true
    assert_inside_shell('[data-voice-recorder-target="sheet"]')

    # 오버레이가 앱의 높이까지 덮어 하단 탭 위에서도 정상 표시되어야 한다.
    sheet = bounds('[data-voice-recorder-target="sheet"]')
    shell = bounds("#app-shell")
    assert_in_delta shell.fetch("top"), sheet.fetch("top"), 1
    assert_in_delta shell.fetch("bottom"), sheet.fetch("bottom"), 1
    # 아이콘만 있는 버튼은 aria-label에 지정된 접근성 이름으로 찾는다.
    click_button "Close recorder", enable_aria_label: true
    assert_no_selector '[data-voice-recorder-target="sheet"]', visible: true
  end

  private

  def visit_screen(screen)
    if screen == :login
      visit new_session_path
      assert_selector "h1", exact_text: "Say One Thing"
    else
      sign_in(user: users(:english_native))
      visit(screen == :say ? rooms_path : settings_path)
      assert_selector "#bottom-tab-bar"
    end
  end

  def bounds(selector)
    page.evaluate_script(<<~JS)
      (() => {
        const rect = document.querySelector(#{selector.to_json}).getBoundingClientRect();
        return { left: rect.left, right: rect.right, top: rect.top, bottom: rect.bottom, width: rect.width };
      })()
    JS
  end

  def assert_inside_shell(selector)
    shell = bounds("#app-shell")
    element = bounds(selector)
    assert_operator element.fetch("left"), :>=, shell.fetch("left") - 1, "#{selector}의 왼쪽이 앱 영역을 벗어났다."
    assert_operator element.fetch("right"), :<=, shell.fetch("right") + 1, "#{selector}의 오른쪽이 앱 영역을 벗어났다."
  end
end
