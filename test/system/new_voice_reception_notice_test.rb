require "application_system_test_case"

class NewVoiceReceptionNoticeTest < ApplicationSystemTestCase
  setup do
    # 수신 중인 사용자로 시작하여 각 테스트의 초기 상태를 명확하게 고정한다.
    @user = users(:english_native)
    @user.update!(receive_new_rooms: true)
    sign_in(user: @user)
    visit rooms_path
  end

  test "r_새 음성 수신을 끄면 기존 대화는 유지된다는 중앙 토스트가 잠시 표시된다" do
    click_button "Receive new rooms", enable_aria_label: true

    # 버튼 상태와 서버 저장 상태를 함께 확인한다.
    # 안내만 바뀌고 실제 수신 설정은 그대로인 경우를 방지한다.
    assert_selector 'button[aria-label="Receive new rooms"][aria-pressed="false"]'
    assert_not @user.reload.receive_new_rooms?
    assert_centered_temporary_notice "New voices are paused. Messages in existing conversations are unaffected."
  end

  test "r_새 음성 수신을 다시 켜면 수신 허용 중앙 토스트가 잠시 표시된다" do
    # 화면에서 먼저 수신을 끈 뒤 다시 켠다. 사용자의 실제 전환 경로를 검증한다.
    click_button "Receive new rooms", enable_aria_label: true
    assert_selector 'button[aria-label="Receive new rooms"][aria-pressed="false"]'
    click_button "Receive new rooms", enable_aria_label: true

    assert_selector 'button[aria-label="Receive new rooms"][aria-pressed="true"]'
    assert @user.reload.receive_new_rooms?
    assert_centered_temporary_notice "New voices are allowed."
  end

  private

  def assert_centered_temporary_notice(message)
    # 스크린샷처럼 메시지가 화면 중앙에 떠야 한다.
    # 상단 일반 flash로 출력하는 구현은 문구가 같더라도 통과시키지 않는다.
    # role=status는 스크린리더에도 설정 변경 결과를 전달한다.
    assert_selector '[role="status"]', exact_text: message
    notice = find('[role="status"]', exact_text: message)
    geometry = notice.evaluate_script(<<~JS)
      (() => {
        const rect = this.getBoundingClientRect();
        return {
          x: rect.left + rect.width / 2,
          y: rect.top + rect.height / 2,
          viewportX: window.innerWidth / 2,
          viewportY: window.innerHeight / 2,
          position: window.getComputedStyle(this).position
        };
      })()
    JS
    assert_equal "fixed", geometry.fetch("position")
    assert_in_delta geometry.fetch("viewportX"), geometry.fetch("x"), 24
    assert_in_delta geometry.fetch("viewportY"), geometry.fetch("y"), 24

    # 사용자가 닫지 않아도 6초 안에 사라져야 한다.
    # sleep 대신 Capybara의 대기를 사용하여 실제 표시 시간에 맞춰 검사한다.
    assert_no_selector '[role="status"]', exact_text: message, wait: 6
  end
end
