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

  test "r_Korean을 선택하고 새로고침하면 선택과 룸 목록이 유지된다" do
    assert_language_survives_refresh(languages(:korean), languages(:english))
  end

  test "r_English를 선택하고 새로고침하면 선택과 룸 목록이 유지된다" do
    assert_language_survives_refresh(languages(:english), languages(:korean))
  end

  test "r_룸 목록에서 내 차례는 기본 배경으로 상대방 답장 대기는 흐린 배경으로 표시한다" do
    my_turn_room = Room.create!(host: @other, opponent: @user, language: @room_language)
    create_voice_message(room: my_turn_room, sender: @other)

    waiting_room = Room.create!(host: @other, opponent: @user, language: @room_language)
    create_voice_message(room: waiting_room, sender: @other)
    create_voice_message(room: waiting_room, sender: @user)

    visit rooms_path

    assert_selector "a[href='#{room_path(my_turn_room)}'].bg-white"
    assert_selector "a[href='#{room_path(waiting_room)}'].bg-slate-100"

    find("a[href='#{room_path(waiting_room)}']").click
    assert_current_path room_path(waiting_room)
  end

  test "r_룸 링크 오른쪽의 연한 빨간색 배지에 해당 룸의 전체 음성 개수를 표시한다" do
    room = Room.create!(host: @other, opponent: @user, language: @room_language)
    [ @other, @user, @other ].each do |sender|
      create_voice_message(room: room, sender: sender)
    end

    other_room = Room.create!(host: @other, opponent: @user, language: @room_language)
    create_voice_message(room: other_room, sender: @other)

    visit rooms_path

    [ [ room, 3 ], [ other_room, 1 ] ].each do |conversation, count|
      link_selector = "a[href='#{room_path(conversation)}']"
      assert_selector "#{link_selector} .bg-red-100.text-red-700", exact_text: count.to_s, count: 1

      link = find(link_selector)
      badge = link.find(".bg-red-100.text-red-700")
      link_center = link.evaluate_script("this.getBoundingClientRect().left + this.getBoundingClientRect().width / 2")
      badge_left = badge.evaluate_script("this.getBoundingClientRect().left")
      assert_operator badge_left, :>, link_center
      assert_operator badge.evaluate_script("this.getBoundingClientRect().right"), :<=, link.evaluate_script("this.getBoundingClientRect().right")
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
