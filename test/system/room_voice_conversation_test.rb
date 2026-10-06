require "application_system_test_case"
require "minitest/mock"
require_relative "../test_helpers/voice_test_helper"

class RoomVoiceConversationTest < ApplicationSystemTestCase
  include VoiceTestHelper

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ] do |options|
    options.add_argument "--mute-audio"
    options.add_argument "--use-fake-device-for-media-stream"
    options.add_argument "--use-fake-ui-for-media-stream"
    options.add_argument "--autoplay-policy=no-user-gesture-required"
  end

  setup do
    @sender = users(:english_native)
    @recipient = users(:korean_native)
    @other_recipient = users(:spanish_native)
    @outsider = users(:japanese_native)
    @room_language = languages(:korean)
    [ @recipient, @other_recipient ].each do |user|
      user.update!(native_language: @room_language, learning_language: languages(:english), last_active_at: Time.current)
    end
  end

  test "r_Say에서 녹음을 전송하면 수신자의 Say 탭에 해당 언어의 룸이 표시된다" do
    previous_ids = Room.pluck(:id)

    as_user(@sender) do
      visit rooms_path
      select @room_language.label, from: "room_language_id"
      assert_select "room_language_id", selected: @room_language.label
      record_and_send("Drop a voice")
      assert_current_path rooms_path, ignore_query: true
    end

    rooms = Room.where.not(id: previous_ids)
    assert_equal [ @recipient.id, @other_recipient.id ].sort, rooms.pluck(:opponent_id).sort
    assert_equal [ @sender.id ], rooms.distinct.pluck(:host_id)
    assert_equal [ @room_language.id ], rooms.distinct.pluck(:language_id)

    [ @recipient, @other_recipient ].each do |user|
      received_room = rooms.find_by!(opponent: user)
      other_recipient_room = rooms.where.not(opponent: user).sole
      assert received_room.voice_messages.sole.audio.attached?

      as_user(user) do
        visit rooms_path
        select @room_language.label, from: "room_language_id"
        assert_select "room_language_id", selected: @room_language.label
        assert_selector "main a[href='#{room_path(received_room)}']"
        assert_no_selector "main a[href='#{room_path(other_recipient_room)}']"
      end
    end

    [ @sender, @outsider ].each do |user|
      as_user(user) do
        visit rooms_path
        rooms.each { |room| assert_no_selector "main a[href='#{room_path(room)}']" }
      end
    end
  end

  test "r_수신자는 룸에 들어가 발신자가 보낸 음성을 재생할 수 있다" do
    room = create_conversation(@recipient)
    assert_equal voice_audio, room.voice_messages.sole.audio.download

    as_user(@recipient) do
      open_conversation(room)
      assert_selector "h1", text: @sender.display_name
      assert_selector "main article audio[controls]", count: 1
      assert_audio_plays(find("main article audio"))
    end
  end

  test "r_수신자가 처음 답장하면 발신자의 Say 탭에도 룸이 표시된다" do
    room = create_conversation(@recipient)

    as_user(@sender) do
      visit rooms_path
      assert_no_selector "main a[href='#{room_path(room)}']"
    end

    as_user(@recipient) do
      open_conversation(room)
      assert_difference -> { room.voice_messages.count }, 1 do
        record_and_send("Reply with voice")
        assert_selector "main article audio", count: 2
      end
    end

    reply = room.voice_messages.where(sender: @recipient).sole
    assert reply.audio.attached?

    as_user(@sender) do
      open_conversation(room)
      assert_selector "main article audio", count: 2
      assert_audio_plays(all("main article audio").last)
    end
  end

  test "r_룸에서 주고받는 답장은 새 매칭 없이 해당 룸에만 저장된다" do
    room = create_conversation(@recipient)
    other_room = create_conversation(@other_recipient)
    other_message_ids = other_room.voice_messages.pluck(:id)
    reject_matching = ->(**) { flunk "룸 답장은 수신자 선정 알고리즘을 호출하면 안 됩니다." }

    VoiceRecipientSelector.stub(:recipients, reject_matching) do
      assert_no_difference "Room.count" do
        assert_difference -> { room.voice_messages.count }, 2 do
          as_user(@recipient) do
            open_conversation(room)
            record_and_send("Reply with voice")
            assert_selector "main article audio", count: 2
          end

          as_user(@sender) do
            open_conversation(room)
            record_and_send("Reply with voice")
            assert_selector "main article audio", count: 3
          end
        end
      end
    end

    assert_equal [ @sender.id, @recipient.id, @sender.id ], room.voice_messages.order(:created_at, :id).pluck(:sender_id)
    assert_equal other_message_ids, other_room.voice_messages.order(:id).pluck(:id)

    as_user(@other_recipient) do
      open_conversation(other_room)
      assert_selector "main article audio", count: 1
    end
  end

  test "r_룸 참여자가 아닌 사용자는 주소를 직접 입력해도 대화를 볼 수 없다" do
    room = create_conversation(@recipient)

    as_user(@outsider) do
      result = fetch_as_current_user(room_path(room))
      assert_equal 404, result.fetch("status")
      assert_not_includes result.fetch("body"), @sender.display_name
      assert_no_match(/<audio\b/i, result.fetch("body"))
    end
  end

  test "r_룸 참여자가 아닌 사용자는 음성 주소로 직접 접근해도 재생할 수 없다" do
    room = create_conversation(@recipient)
    audio_url = nil

    as_user(@recipient) do
      open_conversation(room)
      audio = find("main article audio")
      assert_audio_plays(audio)
      audio_url = audio[:src]
    end

    as_user(@outsider) do
      result = fetch_as_current_user(audio_url)
      assert_includes [ 403, 404 ], result.fetch("status")
      refute result.fetch("content_type").start_with?("audio/")
    end
  end

  private

  def as_user(user)
    using_session("room_voice_#{user.id}") do
      sign_in(user: user)
      yield
    end
  end

  def create_conversation(recipient)
    room = Room.create!(host: @sender, opponent: recipient, language: @room_language)
    create_voice_message(room: room, sender: @sender)
    room
  end

  def open_conversation(room)
    visit rooms_path
    select @room_language.label, from: "room_language_id"
    assert_select "room_language_id", selected: @room_language.label
    find("main a[href='#{room_path(room)}']").click
    assert_current_path room_path(room)
  end

  def record_and_send(trigger)
    click_button trigger
    within '[data-voice-recorder-target="sheet"]' do
      click_button "Start recording", enable_aria_label: true
      assert_selector '[data-voice-recorder-target="timer"]', text: "00:02", wait: 5
      click_button "Stop recording", enable_aria_label: true
      assert_selector 'audio[src^="blob:"]'
      click_button "Send voice"
    end
    assert_no_selector '[data-voice-recorder-target="sheet"]', wait: 10
  end

  def assert_audio_plays(audio)
    audio.execute_script("this.play()")
    assert audio.synchronize(5, errors: [ Capybara::ExpectationNotMet ]) {
      raise Capybara::ExpectationNotMet, "음성 재생 시간이 증가하지 않습니다." unless audio.evaluate_script("this.currentTime > 0 && !this.error")
      true
    }
  end

  def fetch_as_current_user(url)
    page.evaluate_async_script(<<~JS, url)
      const done = arguments[arguments.length - 1];
      fetch(arguments[0], { credentials: "same-origin", cache: "no-store" })
        .then(async response => done({
          status: response.status,
          content_type: response.headers.get("content-type") || "",
          body: await response.text()
        }))
        .catch(error => done({ status: 0, content_type: "", body: String(error) }));
    JS
  end
end
