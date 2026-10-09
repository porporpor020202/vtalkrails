require "application_system_test_case"

class NativeLanguageSettingsTest < ApplicationSystemTestCase
  setup do
    @user = users(:english_native)
    sign_in(user: @user)
    visit language_setup_path
  end

  test "모국어 편집 화면에서는 학습 언어 없이 모국어만 변경하고 저장할 수 있다" do
    # 기존 사용자의 모국어는 English이며 학습 언어는 설정하지 않는다.
    # 이제 학습 언어를 선택하지 않아도 모국어를 Korean으로 바꿀 수 있어야 한다.
    # 저장 후 설정 카드와 편집 화면에도 바뀐 모국어가 유지되어야 한다.
    assert_selector "h1", text: "Native language", exact_text: true
    assert_select "user_native_language_id", selected: "English"
    assert_no_selector "#user_learning_language_id", visible: :all
    assert_no_text "learning language", exact: false

    select "Korean", from: "user_native_language_id"
    # 선택만 바꾼 시점에는 저장하지 않는다.
    assert_equal languages(:english), @user.reload.native_language

    click_button "Save changes"
    assert_current_path settings_path
    assert_equal languages(:korean), @user.reload.native_language

    # 저장 결과가 설정 카드에 표시되고 편집 화면을 다시 열어도 유지되는지 확인한다.
    within find_link("Open language settings", enable_aria_label: true) do
      assert_text "Native language"
      assert_text "Korean"
      assert_no_text "Learning language"
    end
    click_link "Open language settings", enable_aria_label: true
    assert_select "user_native_language_id", selected: "Korean"
  end

  test "모국어를 선택하지 않으면 모국어 선택 안내를 표시하고 저장하지 않는다" do
    # 학습 언어를 요구하던 안내 대신 모국어만 선택하도록 안내해야 한다.
    select "Select your native language", from: "user_native_language_id"
    click_button "Save changes"

    within "dialog[open]" do
      assert_text "Please select your native language."
      assert_no_text "learning language", exact: false
      click_button "OK"
    end
    assert_current_path language_setup_path
    assert_equal languages(:english), @user.reload.native_language
  end
end
