require "application_system_test_case"
require_relative "../test_helpers/voice_test_helper"

class AccountDeletionTest < ApplicationSystemTestCase
  include VoiceTestHelper

  setup do
    @user = users(:english_native)
    @session = sign_in(user: @user)

    # 주소를 직접 입력하는 대신 실제 설정 화면에서 삭제 버튼까지 이동한다.
    visit settings_path
    click_link "Open profile", enable_aria_label: true
    assert_current_path profile_path
    assert_button "Delete Account"
  end

  test "계정 삭제 확인창을 취소하면 계정과 로그인 상태를 유지한다" do
    # 복구 불가 안내가 포함된 확인창이 표시되는지 함께 확인한다.
    dismiss_confirm("Delete your account permanently? This cannot be undone.") do
      click_button "Delete Account"
    end

    assert_current_path profile_path
    assert User.exists?(@user.id)
    assert Session.exists?(@session.id)

    # 취소 후에도 인증이 필요한 설정 화면을 사용할 수 있어야 한다.
    visit settings_path
    assert_current_path settings_path
    assert_selector "h1", text: "Setting"
  end

  test "계정을 삭제하면 대화 상대의 Room은 남고 떠나간 사용자라고 안내한다" do
    # 삭제 사용자가 호스트인 방과 수신자인 방을 각각 준비한다.
    # 역할에 따라 상대방의 Room까지 함께 삭제되는 구현을 방지한다.
    partners = [ users(:korean_native), users(:japanese_native) ]
    language = languages(:english)
    conversations = [
      [ Room.create!(host: @user, opponent: partners.first), partners.first ],
      [ Room.create!(host: partners.last, opponent: @user), partners.last ]
    ]

    conversations.each do |room, partner|
      # 양쪽이 음성을 주고받아 상대방 목록에 표시되는 대화를 만든다.
      # 상대방에게 원래 없던 방을 삭제 결과로 오인하지 않게 한다.
      create_voice_message(room: room, sender: @user)
      create_voice_message(room: room, sender: partner)

      using_session("account_deletion_partner_#{partner.id}") do
        sign_in(user: partner)
        visit rooms_path
        assert_selector "main a[href='#{room_path(room)}']"
      end
    end

    # 원래 브라우저 세션의 프로필 화면에서 계정을 삭제한다.
    accept_confirm("Delete your account permanently? This cannot be undone.") do
      click_button "Delete Account"
    end

    assert_current_path new_session_path
    assert_not User.exists?(@user.id)

    conversations.each do |room, partner|
      using_session("account_deletion_partner_#{partner.id}") do
        # 상대방에게 대화는 남기되 삭제된 사용자라고 계속 안내한다.
        visit rooms_path

        within "main a[href='#{room_path(room)}']" do
          assert_text "Former user"
        end

        find("main a[href='#{room_path(room)}']").click

        assert_current_path room_path(room)
        assert_text "Former user"
        assert_no_button "Reply with voice"

        # 새로고침 후에도 안내와 답장 불가 상태를 유지한다.
        page.refresh

        assert_text "Former user"
        assert_no_button "Reply with voice"
      end

      assert Room.exists?(room.id)
    end
  end

  test "계정 삭제를 승인하면 계정을 삭제하고 로그인 화면으로 이동한다" do
    # 다른 기기에 로그인한 세션도 계정 삭제와 함께 제거되어야 한다.
    other_session = @user.sessions.create!

    accept_confirm("Delete your account permanently? This cannot be undone.") do
      click_button "Delete Account"
    end

    # 완료 화면을 기다린 뒤 DB를 확인하여 요청 처리 전 검사를 방지한다.
    assert_current_path new_session_path
    assert_text "Your account and associated data have been deleted."
    assert_not User.exists?(@user.id)
    assert_not Session.exists?(@session.id)
    assert_not Session.exists?(other_session.id)

    # 삭제 전 브라우저 쿠키로 보호된 화면에 다시 접근할 수 없어야 한다.
    visit settings_path
    assert_current_path new_session_path

    # 뒤로가기로 이전 화면에 돌아가도 서버에서 로그인 상태가 복구되지 않는다.
    page.go_back
    page.refresh
    visit profile_path
    assert_current_path new_session_path
  end
end
