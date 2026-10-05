require "application_system_test_case"

class SayTabTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome,
            screen_size: [ 1400, 1000 ] do |options|
    options.add_argument "--use-fake-device-for-media-stream"
    options.add_argument "--use-fake-ui-for-media-stream"
  end

  setup do
    @previous_session_name = Capybara.session_name
    Capybara.session_name = :local_say_tab
    Current.reset

    sign_in(user: users(:english_native))
    within "#bottom-tab-bar" do
      click_link "Say"
    end
    assert_current_path rooms_path
  end

  teardown do
    Capybara.current_session.reset!
    Capybara.session_name = @previous_session_name
    Current.reset
  end

  test "r_Say 화면 맨 위에서 아래로 당기면 현재 화면을 새로고침한다" do
    page.execute_script(<<~JS)
      const section = document
        .querySelector('[data-pull-to-refresh-target="indicator"]')
        .closest("section");

      // 새로고침으로 HTML이 교체되는지 확인하기 위한 임시 표시
      section.dataset.refreshProbe = "before";
      section.closest("main").scrollTop = 0;

      function dispatchTouch(type, y) {
        const event = new Event(type, {
          bubbles: true,
          cancelable: true
        });

        Object.defineProperty(event, "touches", {
          value: [{ clientY: y }]
        });

        section.dispatchEvent(event);
      }

      dispatchTouch("touchstart", 100);
      dispatchTouch("touchmove", 300);
    JS

    assert_selector(
      '[data-pull-to-refresh-target="label"]',
      text: "Release to refresh"
    )

    page.execute_script(<<~JS)
      document.querySelector('[data-refresh-probe="before"]')
        .dispatchEvent(new Event("touchend", { bubbles: true }));
    JS

    assert_no_selector '[data-refresh-probe="before"]'
    assert_current_path rooms_path
    assert_selector '[data-pull-to-refresh-target="label"]', text: "Pull to refresh"
  end

  test "r_Say 탭에서 녹음 버튼을 누르면 녹음 창이 열린다" do
    assert_no_selector recorder_sheet

    click_button "Drop a voice"

    within recorder_sheet do
      assert_selector '[data-voice-recorder-target="timer"]'
    end
  end

  test "r_녹음을 완료하면 미리듣기와 Record again 버튼이 표시된다" do
    start_and_finish_recording_with_click_drop_a_voice

    within recorder_sheet do
      assert_selector 'audio[src^="blob:"]'
      assert_no_selector '[data-voice-recorder-target="recordingMessage"]'
      assert_button "Record again"
      assert_button "Send voice"
      assert_no_button "Start recording", enable_aria_label: true
      assert_no_button "Stop recording", enable_aria_label: true
    end
  end

  test "Send voice를 누르면 현재 선택된 언어 ID와 녹음이 전송된다" do
    user = users(:english_native)

    # 기본값인 학습 언어에서 모국어로 변경해 현재 선택값을 검증한다.
    select user.native_language.label, from: "say_language_id"
    assert_select "say_language_id", selected: user.native_language.label

    observe_voice_drop_request
    record_voice

    within recorder_sheet do
      click_button "Send voice"
    end

    Selenium::WebDriver::Wait.new(timeout: 10).until do
      page.evaluate_script("window.voiceDropRequest?.status != null")
    end

    request = page.evaluate_script("window.voiceDropRequest")

    assert_equal user.native_language_id.to_s, request["language_id"]
    assert_operator request["audio_size"], :>, 0
    assert_equal 201, request["status"]

    drop = VoiceDrop.find_by!(sender: user, request_key: request["request_key"])
    message = VoiceMessage.where(
      sender: user,
      room_id: drop.rooms.select(:id)
    ).order(:id).last

    assert_not_nil message
    assert message.audio.attached?
  end

  test "r_Record again을 누르면 기존 녹음이 지워지고 다시 녹음할 수 있다" do
    start_and_finish_recording_with_click_drop_a_voice

    within recorder_sheet do
      assert_selector 'audio[src^="blob:"]'

      click_button "Record again"

      assert_selector "audio:not([src])", visible: :all
      assert_selector '[data-voice-recorder-target="timer"]', exact_text: "00:00"
      assert_button "Start recording", enable_aria_label: true
      assert_no_button "Record again"
      assert_no_button "Send voice"

      start_and_finish_recording_within_sheet

      assert_selector 'audio[src^="blob:"]'
      assert_button "Record again"
      assert_button "Send voice"
    end
  end

  test "r_녹음 완료 후 X를 눌러 닫으면 기존 녹음이 삭제된다" do
    start_and_finish_recording_with_click_drop_a_voice

    within recorder_sheet do
      assert_button "Record again"
      assert_selector 'audio[src^="blob:"]'

      click_button "Close recorder", enable_aria_label: true
    end

    assert_no_selector recorder_sheet

    click_button "Drop a voice"

    within recorder_sheet do
      assert_selector "audio:not([src])", visible: :all
      assert_selector '[data-voice-recorder-target="timer"]', exact_text: "00:00"
      assert_button "Start recording", enable_aria_label: true
      assert_no_button "Record again"
      assert_no_button "Send voice"
    end
  end

  test "r_Say 탭의 언어 목록에는 학습 언어와 모국어가 순서대로 표시된다" do
    user = users(:english_native)
    expected_languages = [ user.learning_language, user.native_language ]

    within "header" do
      assert_selector "#say_language_id option", count: 2, visible: :all
      options = all("#say_language_id option", visible: :all)

      # TODO: &:label 공식문서 확인하자.
      assert_equal expected_languages.map(&:label), options.map { |option| option.text(:all) }
      assert_equal expected_languages.map { |language| language.id.to_s }, options.map { |option| option[:value] }
      assert_select "say_language_id", selected: user.learning_language.label
    end
  end

  private

  def recorder_sheet
    '[data-voice-recorder-target="sheet"]'
  end

  def start_and_finish_recording_with_click_drop_a_voice
    click_button "Drop a voice"

    within recorder_sheet do
      start_and_finish_recording_within_sheet
    end
  end

  def start_and_finish_recording_within_sheet
    click_button "Start recording", enable_aria_label: true

    assert_button "Stop recording", enable_aria_label: true
    assert_selector '[data-voice-recorder-target="timer"]', text: /00:03/, wait: 5

    click_button "Stop recording", enable_aria_label: true

    assert_button "Record again"
  end

  def observe_voice_drop_request
    page.execute_script(<<~JS)
      const originalFetch = window.fetch.bind(window);
      const endpoint = #{voice_drop_path.to_json};

      window.voiceDropRequest = null;

      window.fetch = async function(url, options = {}) {
        if (
          new URL(url, window.location.href).pathname !== endpoint ||
          options.method !== "POST"
        ) {
          return originalFetch(url, options);
        }

        const body = options.body;
        const request = {
          language_id: body.get("say_language_id"),
          request_key: body.get("request_key"),
          audio_size: body.get("voice_message[audio]")?.size || 0,
          status: null
        };

        window.voiceDropRequest = request;

        // 실제 서버로 전송한다. 성공 응답을 가짜로 만들지 않는다.
        const response = await originalFetch(url, options);
        request.status = response.status;

        return response;
      };
    JS
  end
end
