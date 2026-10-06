require "application_system_test_case"
require_relative "../test_helpers/voice_test_helper"

class SayTabTest < ApplicationSystemTestCase
  include VoiceTestHelper

  driven_by :selenium, using: :headless_chrome,
            screen_size: [ 1400, 1000 ] do |options|
    options.add_argument "--mute-audio"
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

  test "r_Say 탭에서 선택한 언어의 룸만 표시된다" do
    host = users(:korean_native)
    opponent = users(:english_native)

    english_room = Room.create!(
      host: host,
      opponent: opponent,
      language: languages(:english)
    )

    korean_room = Room.create!(
      host: host,
      opponent: opponent,
      language: languages(:korean)
    )

    visit rooms_path

    select "English", from: "room_language_id"
    assert_select "room_language_id", selected: "English"

    within "main" do
      assert_selector "a[href='#{room_path(english_room)}']"
      assert_no_selector "a[href='#{room_path(korean_room)}']"
    end

    select "Korean", from: "room_language_id"
    assert_select "room_language_id", selected: "Korean"

    within "main" do
      assert_selector "a[href='#{room_path(korean_room)}']"
      assert_no_selector "a[href='#{room_path(english_room)}']"
    end
  end

  test "Say 탭에서 내가 참여하지 않은 룸은 표시되지 않는다" do
    user = users(:english_native)
    other = users(:korean_native)
    room_language = languages(:korean)

    received_room = Room.create!(
      host: other,
      opponent: user,
      language: room_language
    )

    unrelated_room = Room.create!(
      host: other,
      opponent: users(:japanese_native),
      language: room_language
    )

    visit rooms_path
    assert_select "room_language_id", selected: room_language.label

    within "main" do
      assert_selector "a[href='#{room_path(received_room)}']"
      assert_no_selector "a[href='#{room_path(unrelated_room)}']"
    end
  end

  test "r_Say 탭에서 내가 호스트이고 아직 답장이 없는 룸은 표시되지 않는다" do
    user = users(:english_native)
    other = users(:korean_native)
    room_language = languages(:korean)

    unanswered_room = Room.create!(host: user, opponent: other, language: room_language)
    create_voice_message(room: unanswered_room, sender: user)

    answered_room = Room.create!(host: user, opponent: other, language: room_language)
    create_voice_message(room: answered_room, sender: user)
    create_voice_message(room: answered_room, sender: other)

    received_room = Room.create!(host: other, opponent: user, language: room_language)
    create_voice_message(room: received_room, sender: other)

    visit rooms_path
    assert_select "room_language_id", selected: room_language.label

    within "main" do
      assert_selector "a[href='#{room_path(answered_room)}']"
      assert_selector "a[href='#{room_path(received_room)}']"
      assert_no_selector "a[href='#{room_path(unanswered_room)}']"
    end
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

  test "Say 탭의 언어 목록에는 학습 언어와 모국어가 순서대로 표시된다" do
    user = users(:english_native)
    expected_languages = [ user.learning_language, user.native_language ]

    within "header" do
      assert_selector "#room_language_id option", count: 2, visible: :all
      options = all("#room_language_id option", visible: :all)

      # TODO: &:label 공식문서 확인하자.
      assert_equal expected_languages.map(&:label), options.map { |option| option.text(:all) }
      assert_equal expected_languages.map { |language| language.id.to_s }, options.map { |option| option[:value] }
      assert_select "room_language_id", selected: user.learning_language.label
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
end
