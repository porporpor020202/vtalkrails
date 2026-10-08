require "application_system_test_case"

class SignOutNoticeTest < ApplicationSystemTestCase
  test "r_로그아웃 안내는 로그인 버튼 위에 한 번만 표시되고 좌측 상단에는 표시되지 않는다" do
    # 실제 로그인과 프로필의 로그아웃 버튼을 거친다.
    # session/new를 바로 방문하면 flash가 없으므로 중복 출력 버그를 재현할 수 없다.
    sign_in(user: users(:english_native))
    visit profile_path
    click_button "Sign Out"

    assert_current_path new_session_path
    assert_selector "h1", exact_text: "Say One Thing"

    # 로그인 화면의 기존 안내 상자는 유지하고 같은 문구를 담은 요소는 하나만 허용한다.
    # exact_text를 사용하여 자식 텍스트를 포함한 부모 요소까지 중복으로 세지 않는다.
    assert_selector "span", exact_text: "You have signed out."
    assert_selector "main p, main span", exact_text: "You have signed out.", count: 1

    # 공통 레이아웃이 본문 앞에 출력하던 일반 flash 문단이 없어야 한다.
    # 문구 자체를 모두 숨겨서 위의 중복 개수 검사만 통과하는 것을 방지한다.
    assert_no_selector "main > p", exact_text: "You have signed out."
  end
end
