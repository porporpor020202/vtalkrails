require "application_system_test_case"

class MicrophonePermissionTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome,
            screen_size: [1400, 1000] do |options|
    options.add_argument "--use-fake-device-for-media-stream"
    options.add_argument "--use-fake-ui-for-media-stream"
  end

  setup do
    sign_in(user: users(:english_native))
    visit rooms_path
    click_button "Drop a voice"

    # 브라우저가 마이크 권한 거부를 반환하는 상황을 재현한다.
    page.execute_script(<<~JS)
      window.originalGetUserMedia =
        navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices);

      navigator.mediaDevices.getUserMedia = async () => {
        throw new DOMException("Permission denied", "NotAllowedError");
      };
    JS
  end

  test "마이크 권한을 거부하면 안내를 표시하고 녹음과 전송을 진행하지 않는다" do
    assert_no_difference ["VoiceDrop.count", "Room.count", "VoiceMessage.count"] do
      within recorder_sheet do
        click_button "Start recording", enable_aria_label: true

        assert_selector '[role="alert"]', text: permission_message
        assert_selector '[data-voice-recorder-target="timer"]', exact_text: "00:00"
        assert_button "Start recording", enable_aria_label: true, disabled: false
        assert_no_button "Stop recording", enable_aria_label: true
        assert_no_button "Send voice"
        assert_no_selector 'audio[src]', visible: :all
      end
    end
  end

  test "권한 거부 후 마이크 사용이 허용되면 다시 녹음할 수 있다" do
    within recorder_sheet do
      click_button "Start recording", enable_aria_label: true
      assert_selector '[role="alert"]', text: permission_message

      # 권한 변경 후 실제 테스트용 마이크를 사용할 수 있는 상태로 복구한다.
      page.execute_script(<<~JS)
        navigator.mediaDevices.getUserMedia = window.originalGetUserMedia;
      JS

      click_button "Start recording", enable_aria_label: true

      assert_button "Stop recording", enable_aria_label: true
      assert_selector '[data-voice-recorder-target="timer"]', text: "00:02", wait: 5
      assert_no_selector '[role="alert"]', text: permission_message

      click_button "Stop recording", enable_aria_label: true

      assert_selector 'audio[src^="blob:"]'
      assert_button "Send voice", disabled: false
    end
  end

  test "마이크 권한을 거부해도 녹음 창을 닫을 수 있다" do
    within recorder_sheet do
      click_button "Start recording", enable_aria_label: true
      assert_selector '[role="alert"]', text: permission_message

      click_button "Close recorder", enable_aria_label: true
    end

    assert_no_selector recorder_sheet
    assert_current_path rooms_path
  end

  private

  def recorder_sheet
    '[data-voice-recorder-target="sheet"]'
  end

  def permission_message
    "Allow microphone access in your browser or device settings, then try again."
  end
end
