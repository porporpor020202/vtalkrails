require "application_system_test_case"
require_relative "../test_helpers/voice_test_helper"

class SayTabStateTest < ApplicationSystemTestCase
  include VoiceTestHelper

  setup do
    @user = users(:english_native)
    @other = users(:korean_native)

    sign_in(user: @user)
  end

  test "언어 선택 없이 새로고침하면 룸 목록이 유지된다" do
    # 언어 필터 없이도 새 요청에서 참여 중인 룸을 다시 조회해야 한다.
    room = Room.create!(host: @other, opponent: @user)
    visit rooms_path
    page.refresh
    assert_selector "#room-list a[href='#{room_path(room)}']"
    assert_no_selector "#room_language_id", visible: :all
  end

  test "룸 목록에서 내 차례는 기본 배경으로 상대방 답장 대기는 흐린 배경으로 표시한다" do
    my_turn_room = Room.create!(host: @other, opponent: @user)
    create_voice_message(room: my_turn_room, sender: @other)

    waiting_room = Room.create!(host: @other, opponent: @user)
    create_voice_message(room: waiting_room, sender: @other)
    create_voice_message(room: waiting_room, sender: @user)

    visit rooms_path

    assert_selector "a[href='#{room_path(my_turn_room)}'].bg-white"
    assert_selector "a[href='#{room_path(waiting_room)}'].bg-slate-100"

    find("a[href='#{room_path(waiting_room)}']").click
    assert_current_path room_path(waiting_room)
  end

  test "룸 링크 오른쪽의 연한 빨간색 배지에 해당 룸의 전체 음성 개수를 표시한다" do
    room = Room.create!(host: @other, opponent: @user)
    [ @other, @user, @other ].each do |sender|
      create_voice_message(room: room, sender: sender)
    end

    other_room = Room.create!(host: @other, opponent: @user)
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

  test "룸이 100개를 넘어도 목록만 스크롤되고 녹음 버튼은 제자리에 있다" do
    101.times { Room.create!(host: @other, opponent: @user) }
    visit rooms_path
    assert_selector "#room-list a", count: 101

    recorder = find_button("Drop a voice")
    recorder_top = recorder.evaluate_script("this.getBoundingClientRect().top")
    list = find("#room-list")
    assert list.evaluate_script("this.scrollHeight > this.clientHeight"), "The room list itself must be scrollable."

    list.execute_script("this.scrollTop = this.scrollHeight")

    assert_operator list.evaluate_script("this.scrollTop"), :>, 0
    assert_in_delta recorder_top, recorder.evaluate_script("this.getBoundingClientRect().top"), 1
    assert_equal 0, page.evaluate_script("document.querySelector('main').scrollTop")
    assert_equal 0, page.evaluate_script("document.scrollingElement.scrollTop")
    assert recorder.evaluate_script("this.getBoundingClientRect().top >= 0 && this.getBoundingClientRect().bottom <= innerHeight")
  end

end
