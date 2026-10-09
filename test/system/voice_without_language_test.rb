require "application_system_test_case"

class VoiceWithoutLanguageTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ] do |options|
    options.add_argument "--mute-audio"
    options.add_argument "--use-fake-device-for-media-stream"
    options.add_argument "--use-fake-ui-for-media-stream"
  end

  test "학습 언어와 룸 언어 없이 음성을 전송하고 상대방이 답장할 수 있다" do
    # 수신 가능한 사람을 한 명으로 고정해 언어 조건 때문에 매칭에서 빠지는지 확인한다.
    # 두 사람 모두 모국어가 Korean이고 학습 언어가 없지만 영어 대화 앱을 사용할 수 있다.
    User.update_all(last_active_at: nil)
    sender = users(:english_native)
    recipient = users(:korean_native)
    [ sender, recipient ].each do |user|
      user.update!(native_language: languages(:korean),
                   last_active_at: Time.current, receive_new_rooms: true)
    end

    using_session(:voice_without_language_sender) do
      sign_in(user: sender)
      visit rooms_path
      assert_no_selector "#room_language_id", visible: :all
      record_and_send("Drop a voice")
      assert_current_path rooms_path
    end

    drop = sender.voice_drops.sole
    room = Room.find_by!(host: sender, opponent: recipient)
    assert_equal 1, drop.recipient_count
    assert room.voice_messages.sole.audio.attached?

    # 기존 English 룸으로 자동 지정하는 방식 대신 언어 없는 대화를 생성해야 한다.
    # 추후 컬럼 자체를 삭제해도 유효하도록 실제 저장된 attributes를 확인한다.
    assert_nil room.attributes["language_id"]
    assert_nil drop.attributes["language_id"]

    using_session(:voice_without_language_recipient) do
      sign_in(user: recipient)
      visit rooms_path
      # 목록 조회에도 룸 언어 조건이 남아 있으면 새 대화가 보이지 않는다.
      assert_selector "main a[href='#{room_path(room)}']"
      find("main a[href='#{room_path(room)}']").click
      record_and_send("Reply with voice")
      assert_current_path room_path(room)
    end

    assert_equal [ sender.id, recipient.id ], room.voice_messages.order(:id).pluck(:sender_id)
    assert room.voice_messages.order(:id).last.audio.attached?

    using_session(:voice_without_language_sender) do
      visit rooms_path
      assert_selector "main a[href='#{room_path(room)}']"
    end
  end

  private

  def record_and_send(button)
    click_button button
    within '[data-voice-recorder-target="sheet"]' do
      click_button "Start recording", enable_aria_label: true
      assert_selector '[data-voice-recorder-target="timer"]', text: "00:02", wait: 5
      click_button "Stop recording", enable_aria_label: true
      assert_selector 'audio[src^="blob:"]'
      click_button "Send voice"
    end
    # 'Try again'으로 남는 현재 오류를 실제 녹음·전송 경로에서 잡는다.
    assert_no_selector '[data-voice-recorder-target="sheet"]', wait: 10
  end
end
