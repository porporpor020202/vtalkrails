require "application_system_test_case"
require_relative "../test_helpers/voice_test_helper"

class NativeLanguageRoomFlowTest < ApplicationSystemTestCase
  include VoiceTestHelper

  driven_by :selenium, using: :headless_chrome, screen_size: [390, 844] do |options|
    options.add_argument "--mute-audio"
    options.add_argument "--use-fake-device-for-media-stream"
    options.add_argument "--use-fake-ui-for-media-stream"
  end

  test "sending a recording matches only the native language and the index follows the selected language" do
    sender = users(:english_native)
    english_recipient = users(:korean_native)
    english_recipient.update!(native_language: languages(:english), last_active_at: Time.current)
    spanish_recipient = users(:spanish_native)
    spanish_recipient.update!(last_active_at: Time.current)
    languages(:spanish).update!(enable: true)

    # Both language spaces have a received conversation, so an empty list cannot pass.
    english_room = Room.create!(host: english_recipient, opponent: sender)
    spanish_room = Room.create!(host: spanish_recipient, opponent: sender)
    create_voice_message(room: english_room, sender: english_recipient)
    create_voice_message(room: spanish_room, sender: spanish_recipient)

    sign_in(user: sender)
    visit rooms_path
    assert_selector ".voice-inbox-header", text: "Language: English"
    assert_selector "a[href='#{room_path(english_room)}']"
    assert_no_selector "a[href='#{room_path(spanish_room)}']"

    assert_difference "Room.count", 1 do
      click_button "Drop a voice"
      within '[data-voice-recorder-target="sheet"]' do
        click_button "Start recording", enable_aria_label: true
        assert_selector '[data-voice-recorder-target="timer"]', text: "00:02", wait: 5
        click_button "Stop recording", enable_aria_label: true
        assert_selector 'audio[src^="blob:"]'
        click_button "Send voice"
      end
      assert_no_selector '[data-voice-recorder-target="sheet"]', wait: 10
      assert_current_path rooms_path
    end

    drop = sender.voice_drops.sole
    assert_equal languages(:english), drop.native_language
    assert_equal [english_recipient.id], drop.rooms.pluck(:opponent_id)
    sent_room = drop.rooms.sole
    assert_equal languages(:english), sent_room.native_language
    assert_equal sender, sent_room.voice_messages.sole.sender
    assert sent_room.voice_messages.sole.audio.attached?
    assert_not drop.rooms.exists?(opponent: spanish_recipient)

    # A reply makes the sent room visible under the existing inbox rules.
    create_voice_message(room: sent_room, sender: english_recipient)
    visit rooms_path
    assert_selector ".voice-inbox-row", count: 2
    assert_selector "a[href='#{room_path(sent_room)}']"
    assert_no_selector "a[href='#{room_path(spanish_room)}']"

    visit language_setup_path
    select "Spanish", from: "Native language"
    click_button "Save changes"
    assert_current_path settings_path
    assert_equal languages(:spanish), sender.reload.native_language

    visit rooms_path
    assert_selector ".voice-inbox-header", text: "Language: Spanish"
    assert_selector ".voice-inbox-row", count: 1
    assert_selector "a[href='#{room_path(spanish_room)}']"
    assert_no_selector "a[href='#{room_path(english_room)}']"
    assert_no_selector "a[href='#{room_path(sent_room)}']"
  end
end
