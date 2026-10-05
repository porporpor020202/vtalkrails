require "application_system_test_case"
require_relative "../test_helpers/voice_test_helper"

class SayTabStateTest < ApplicationSystemTestCase
  include VoiceTestHelper

  setup do
    @user = users(:english_native)
    @other = users(:korean_native)
    @room_language = languages(:korean)
    sign_in(user: @user)
  end

  test "Korean을 선택하고 새로고침하면 선택과 룸 목록이 유지된다" do
    assert_language_survives_refresh(languages(:korean), languages(:english))
  end

  test "English를 선택하고 새로고침하면 선택과 룸 목록이 유지된다" do
    assert_language_survives_refresh(languages(:english), languages(:korean))
  end

  test "룸 목록에서 내가 답할 차례인 룸을 표시한다" do
    room = Room.create!(host: @other, opponent: @user, language: @room_language)
    create_voice_message(room: room, sender: @other)

    visit rooms_path

    within "a[href='#{room_path(room)}']" do
      assert_text "Your turn"
      assert_no_text "Waiting for reply"
    end
  end

  test "룸 목록에서 상대방의 답장을 기다리는 룸을 표시한다" do
    room = Room.create!(host: @other, opponent: @user, language: @room_language)
    create_voice_message(room: room, sender: @other)
    create_voice_message(room: room, sender: @user)

    visit rooms_path

    within "a[href='#{room_path(room)}']" do
      assert_text "Waiting for reply"
      assert_no_text "Your turn"
    end
  end

  test "룸이 100개를 넘어도 목록만 스크롤되고 언어 선택과 녹음 버튼은 제자리에 있다" do
    101.times { Room.create!(host: @other, opponent: @user, language: @room_language) }
    visit rooms_path
    assert_selector "#room-list a", count: 101

    language = find("#room_language_id")
    recorder = find_button("Drop a voice")
    language_top = language.evaluate_script("this.getBoundingClientRect().top")
    recorder_top = recorder.evaluate_script("this.getBoundingClientRect().top")
    list = find("#room-list")
    assert list.evaluate_script("this.scrollHeight > this.clientHeight"), "룸 목록 자체가 스크롤 영역이어야 합니다."

    list.execute_script("this.scrollTop = this.scrollHeight")

    assert_operator list.evaluate_script("this.scrollTop"), :>, 0
    assert_in_delta language_top, language.evaluate_script("this.getBoundingClientRect().top"), 1
    assert_in_delta recorder_top, recorder.evaluate_script("this.getBoundingClientRect().top"), 1
    assert_equal 0, page.evaluate_script("document.querySelector('main').scrollTop")
    assert_equal 0, page.evaluate_script("document.scrollingElement.scrollTop")
    [ language, recorder ].each do |element|
      assert element.evaluate_script("this.getBoundingClientRect().top >= 0 && this.getBoundingClientRect().bottom <= innerHeight")
    end
  end

  private

  def assert_language_survives_refresh(room_language, other_language)
    room = Room.create!(host: @other, opponent: @user, language: room_language)
    other_room = Room.create!(host: @other, opponent: @user, language: other_language)
    visit rooms_path
    # 기본값이 우연히 일치하는 경우도 확인하도록 다른 언어부터 선택한다.
    select other_language.label, from: "room_language_id"
    assert_selector "#room-list a[href='#{room_path(other_room)}']"
    select room_language.label, from: "room_language_id"
    assert_selector "#room-list a[href='#{room_path(room)}']"
    assert_no_selector "#room-list a[href='#{room_path(other_room)}']"

    page.refresh

    assert_select "room_language_id", selected: room_language.label
    assert_selector "#room-list a[href='#{room_path(room)}']"
    assert_no_selector "#room-list a[href='#{room_path(other_room)}']"
  end
end
