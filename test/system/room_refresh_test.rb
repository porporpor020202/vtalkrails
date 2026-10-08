require "application_system_test_case"
require_relative "../test_helpers/voice_test_helper"

class RoomRefreshTest < ApplicationSystemTestCase
  include VoiceTestHelper

  setup do
    @user = users(:english_native)
    @partner = users(:korean_native)

    sign_in(user: @user)
    visit rooms_path

    # 기본 학습 언어인 Korean 대신 English를 선택한다.
    # 새로고침이 기본 언어로 돌아가는 오류를 확인하기 위한 조건이다.
    select "English", from: "room_language_id"
    assert_select "room_language_id", selected: "English"
    assert_button "Refresh"
  end

  test "r_웹에서 Refresh를 누르면 선택 언어를 유지하며 최신 룸 목록을 표시한다" do
    # 화면을 연 뒤 서버에 룸을 추가한다.
    # 기존 화면에는 없고 새 요청을 보내야만 표시되는 데이터다.
    room = create_received_room
    assert_no_selector "#room-list a[href='#{room_path(room)}']"

    # 전체 페이지를 교체하면 이 DOM 객체가 사라진다.
    # 목록만 갱신하는지 확인하여 녹음 UI 초기화를 방지한다.
    page.execute_script(<<~JS)
      window.originalRecorder =
        document.querySelector('[data-controller="voice-recorder"]');
    JS

    click_button "Refresh"

    assert_selector "#room-list a[href='#{room_path(room)}']"
    assert_select "room_language_id", selected: "English"
    assert_current_path rooms_path(room_language_id: languages(:english).id)

    assert page.evaluate_script(<<~JS)
      window.originalRecorder ===
        document.querySelector('[data-controller="voice-recorder"]')
    JS
  end

  test "r_데스크톱에서는 당기기 안내 대신 클릭할 수 있는 Refresh 버튼을 표시한다" do
    # 데스크톱 사용자가 수행할 수 없는 제스처를 안내하지 않아야 한다.
    assert_no_text "Pull to refresh"
    assert_button "Refresh", disabled: false
  end

  test "r_새로고침 중에는 진행 상태를 표시하고 중복 요청을 막는다" do
    room = create_received_room

    # Turbo 요청을 보내기 직전에 잠시 멈춘다.
    # 임의의 sleep 없이 느린 네트워크 상황을 재현한다.
    # resume을 호출한 뒤에는 실제 Rails 응답으로 목록을 갱신한다.
    page.execute_script(<<~JS)
      window.refreshRequestCount = 0;
      window.holdRefreshRequest = (event) => {
        if (event.target.id !== "room-list") return;

        window.refreshRequestCount += 1;
        event.preventDefault();
        window.resumeRefreshRequest = event.detail.resume;
      };

      document.addEventListener(
        "turbo:before-fetch-request",
        window.holdRefreshRequest
      );
    JS

    click_button "Refresh"

    assert_button "Refreshing…", disabled: true

    # DOM에서 클릭을 다시 시도해도 disabled 버튼은 요청을 만들지 않는다.
    page.execute_script(<<~JS)
      [...document.querySelectorAll("button")]
        .find(button => button.textContent.includes("Refreshing"))
        .click();
    JS
    assert_equal 1, page.evaluate_script("window.refreshRequestCount")

    page.execute_script(<<~JS)
      document.removeEventListener(
        "turbo:before-fetch-request",
        window.holdRefreshRequest
      );
      window.resumeRefreshRequest();
    JS

    assert_selector "#room-list a[href='#{room_path(room)}']"
    assert_button "Refresh", disabled: false
    assert_no_button "Refreshing…"
  end

  private

  def create_received_room
    # 선택 중인 언어로 수신 룸과 음성을 만들어 목록에 표시될 조건을 갖춘다.
    room = Room.create!(
      host: @partner,
      opponent: @user,
      language: languages(:english)
    )
    create_voice_message(room: room, sender: @partner)
    room
  end
end
