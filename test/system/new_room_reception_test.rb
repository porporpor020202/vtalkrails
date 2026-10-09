require "application_system_test_case"
require_relative "../test_helpers/voice_test_helper"

class NewRoomReceptionTest < ApplicationSystemTestCase
  include VoiceTestHelper

  setup do
    @sender = users(:english_native)
    @recipient = users(:korean_native)
    @other_recipient = users(:spanish_native)

    [ @recipient, @other_recipient ].each do |user|
      user.update!(native_language: languages(:korean), last_active_at: Time.current)
    end
    sign_in(user: @recipient)
    visit rooms_path
  end

  test "녹음 버튼 오른쪽에 새 룸 수신 상태를 전환하는 아이콘 버튼이 있다" do
    assert_selector 'button[aria-label="Receive new rooms"][aria-pressed="true"]'
    toggle = find('button[aria-label="Receive new rooms"][aria-pressed="true"]')
    assert_selector 'button[aria-label="Receive new rooms"] svg'
    recorder = find_button("Drop a voice")
    assert_operator toggle.evaluate_script("this.getBoundingClientRect().left"), :>=, recorder.evaluate_script("this.getBoundingClientRect().right")
    assert_in_delta recorder.evaluate_script("this.getBoundingClientRect().top + this.getBoundingClientRect().height / 2"), toggle.evaluate_script("this.getBoundingClientRect().top + this.getBoundingClientRect().height / 2"), 8
  end

  test "새 룸 수신을 끄면 새로고침 후에도 꺼진 상태가 유지된다" do
    set_reception(false)

    page.refresh

    assert_selector 'button[aria-label="Receive new rooms"][aria-pressed="false"]'
  end

  test "수신을 끈 사용자는 언어와 접속 조건이 맞아도 반복 전송에서 새 룸을 받지 않는다" do
    set_reception(false)

    2.times do
      assert_no_difference -> { Room.where(opponent: @recipient).count } do
        assert_difference -> { Room.where(opponent: @other_recipient).count }, 1 do
          dispatch_recording
        end
      end
    end
    assert_not_includes VoiceRecipientSelector.recipients(sender: @sender).map(&:id), @recipient.id
  end

  test "수신을 다시 켜면 매칭 후보에 포함되고 다음 전송에서 새 룸을 받는다" do
    set_reception(false)
    dispatch_recording
    assert_empty Room.where(opponent: @recipient)
    set_reception(true)
    page.refresh
    assert_selector 'button[aria-label="Receive new rooms"][aria-pressed="true"]'

    assert_difference -> { Room.where(opponent: @recipient).count }, 1 do
      dispatch_recording
    end
    received_room = Room.find_by!(host: @sender, opponent: @recipient)
    assert_equal voice_audio, received_room.voice_messages.sole.audio.download
  end

  test "새 룸 수신을 꺼도 기존 룸과 답장 기능은 유지된다" do
    room = Room.create!(host: @sender, opponent: @recipient)
    message = create_voice_message(room: room, sender: @sender)
    set_reception(false)
    assert_selector "#room-list a[href='#{room_path(room)}']"
    find("#room-list a[href='#{room_path(room)}']").click

    assert_current_path room_path(room)
    assert_selector "audio[src='#{audio_room_voice_message_path(room, message)}']"
    assert_button "Reply with voice"
    assert_equal voice_audio, message.reload.audio.download
  end

  private

  def set_reception(enabled)
    assert_selector "button[aria-label='Receive new rooms'][aria-pressed='#{!enabled}']"
    click_button "Receive new rooms", enable_aria_label: true
    assert_selector "button[aria-label='Receive new rooms'][aria-pressed='#{enabled}']"
  end

  def dispatch_recording
    # 화면에서 바꾼 설정을 실제 매칭과 전송 처리에서도 사용하는지 확인한다.
    VoiceDispatcher.new(@sender).call(
      audio: voice_upload,
      duration_ms: 2_000,
      request_key: SecureRandom.uuid
    )
  end
end
