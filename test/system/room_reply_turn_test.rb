require "application_system_test_case"
require_relative "../test_helpers/voice_test_helper"

class RoomReplyTurnSystemTest < ApplicationSystemTestCase
  include VoiceTestHelper

  Capybara.register_driver :room_reply_chrome do |app|
    options = Selenium::WebDriver::Chrome::Options.new
    %w[--headless --mute-audio --window-size=1400,1000 --use-fake-device-for-media-stream --use-fake-ui-for-media-stream].each do |argument|
      options.add_argument argument
    end
    Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
  end
  driven_by :room_reply_chrome

  setup do
    @host = users(:english_native)
    @recipient = users(:korean_native)
    @room_language = languages(:korean)
    @room = Room.create!(host: @host, opponent: @recipient, language: @room_language)
    @first_message = create_voice_message(room: @room, sender: @host)
  end

  test "r_수신자가 답장을 전송하면 녹음 버튼 대신 상대방 답장을 기다리는 안내가 표시된다" do
    sign_in(user: @recipient)
    visit room_path(@room)
    click_button "Reply with voice"
    within '[data-voice-recorder-target="sheet"]' do
      click_button "Start recording", enable_aria_label: true
      assert_selector '[data-voice-recorder-target="timer"]', text: "00:02", wait: 5
      click_button "Stop recording", enable_aria_label: true
      click_button "Send voice"
    end
    assert_no_selector '[data-voice-recorder-target="sheet"]', wait: 10
    assert_selector "main article audio", count: 2

    assert_waiting_for_reply
    page.refresh
    assert_waiting_for_reply
  end

  test "r_호스트도 마지막으로 보낸 사람이면 상대방 답장을 기다린다" do
    sign_in(user: @host)
    visit room_path(@room)

    assert_waiting_for_reply
  end

  test "r_상대방이 답장한 뒤 룸을 다시 열면 녹음 버튼이 표시된다" do
    create_voice_message(room: @room, sender: @recipient)
    sign_in(user: @recipient)
    visit room_path(@room)
    assert_waiting_for_reply

    create_voice_message(room: @room, sender: @host)
    page.refresh

    assert_button "Reply with voice"
    assert_no_text "You can reply after your partner responds."
  end

  test "r_호스트와 수신자 모두 자기 메시지는 오른쪽에 상대방 메시지는 왼쪽에 표시된다" do
    reply = create_voice_message(room: @room, sender: @recipient)

    [ [ @host, @first_message, reply ], [ @recipient, reply, @first_message ] ].each do |user, own_message, partner_message|
      using_session("message_alignment_#{user.id}") do
        sign_in(user: user)
        visit room_path(@room)
        own_audio = find("audio[src='#{audio_room_voice_message_path(@room, own_message)}']")
        partner_audio = find("audio[src='#{audio_room_voice_message_path(@room, partner_message)}']")
        # 호스트 역할이나 CSS 클래스 대신 현재 사용자가 보는 실제 좌우 위치를 검증한다.
        own_center = own_audio.evaluate_script("this.getBoundingClientRect().left + this.getBoundingClientRect().width / 2")
        partner_center = partner_audio.evaluate_script("this.getBoundingClientRect().left + this.getBoundingClientRect().width / 2")
        main_center = find("main").evaluate_script("this.getBoundingClientRect().left + this.getBoundingClientRect().width / 2")
        assert_operator own_center, :>, main_center
        assert_operator partner_center, :<, main_center
      end
    end
  end

  private

  def assert_waiting_for_reply
    assert_no_button "Reply with voice"
    assert_text "You can reply after your partner responds."
  end
end
