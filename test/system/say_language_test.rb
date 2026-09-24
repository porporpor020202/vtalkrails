require "application_system_test_case"

class SayLanguageTest < ApplicationSystemTestCase
  test "어드민 페이지에서 지원 언어를 추가할 수 있다" do
    skip "어드민 기능 추가 후 구현"
    admin = users(:one)
    admin.update!(admin: true)
    sign_in(admin)

    visit "/admin/languages"
    click_on "Add language"
    fill_in "Name", with: "Italian"
    fill_in "Code", with: "it"

    assert_difference "Language.count", 1 do
      click_on "Save"
      assert_text "Italian"
    end

    assert_equal "Italian", Language.find_by!(code: "it").name
  end

  test "채팅방에는 언어를 정확히 한 개 설정해야 한다" do
    english = languages(:english)
    korean = languages(:korean)
    room = Room.new(user: users(:one), opponent: users(:two))

    assert_not room.valid?
    assert room.errors.of_kind?(:language, :blank)

    room.language = english
    room.save!
    assert_equal english, room.reload.language

    room.update!(language: korean)
    assert_equal korean, room.reload.language
    assert_equal :belongs_to, Room.reflect_on_association(:language).macro
  end

  test "Say에서 어드민이 등록한 언어 중 하나를 선택할 수 있다" do
    languages = create_languages
    sign_in(users(:one))
    click_on "Say"

    languages.each do |language|
      assert_selectable_language(language.name)
    end

    # 예시 네 언어를 하드코딩하지 않고 추가된 언어도 제공해야 한다.
    Language.create!(name: "Italian", code: "it")
    visit rooms_path
    assert_selectable_language("Italian")
  end

  test "Say에는 선택한 언어의 방만 표시되고 언어를 바꾸면 목록도 바뀐다" do
    languages = create_languages
    user = users(:one)
    rooms = languages.map do |language|
      Room.create!(
        user: user, opponent: users(:two), language: language,
        last_sender: users(:two), last_message_at: Time.current
      )
    end

    sign_in(user)
    click_on "Say"

    languages.each do |language|
      assert_selectable_language(language.name)

      rooms.each do |room|
        selector = "a[href='#{room_path(room)}']"
        if room.language == language
          assert_selector selector
        else
          assert_no_selector selector
        end
      end
    end
  end

  test "채팅방 언어와 다른 언어의 메시지는 전송할 수 없다" do
    skip "메시지 언어 분석 및 전송 차단은 추후 구현"
  end

  test "Say에서 언어를 선택하고 새로고침해도 해당 언어의 방만 표시된다" do
    rooms = create_languages.map do |language|
      Room.create!(user: users(:one), opponent: users(:two), language: language)
    end
    sign_in(users(:one))
    click_on "Say"

    rooms.each do |room|
      assert_selectable_language(room.language.name)
      assert_selector "a[href='#{room_path(room)}']"
      assert_selector "a[href^='/rooms/']", count: 1

      visit mypage_path
      click_on "Say"
      assert_current_path rooms_path
      assert_select "Language", selected: room.language.name
      refresh

      assert_select "Language", selected: room.language.name
      assert_selector "a[href='#{room_path(room)}']"
      assert_selector "a[href^='/rooms/']", count: 1
    end
  end

  private

  def create_languages
    languages(:english, :spanish, :french, :korean)
  end

  def sign_in(user)
    token = user.signed_id(purpose: :native_auth, expires_in: 5.minutes)
    visit authenticate_by_token_google_oauth_sessions_path(token: token)
    assert_current_path root_path
  end

  def assert_selectable_language(name)
    language_id = Language.find_by!(name: name).id
    already_selected = find(:select, "Language").value == language_id.to_s
    select name, from: "Language"
    unless already_selected
      assert_current_path rooms_path(language_id: language_id)
    end
    assert_select "Language", selected: name
  end
end
