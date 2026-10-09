require "application_system_test_case"

class LanguageSettingsTest < ApplicationSystemTestCase
  setup do
    @user = users(:english_native)
    sign_in(user: @user)
    visit settings_path
  end

  test "설정 카드에는 모국어만 표시된다" do
    # 모국어 표시를 유지하면서 학습 언어 카드가 다시 나타나지 않도록 확인한다.
    within find_link("Open language settings", enable_aria_label: true) do
      assert_text "Native language"
      assert_text "English"
    end
    assert_no_text "Learning language"
  end

  test "모국어 카드를 누르면 모국어 편집 화면이 열린다" do
    click_link "Open language settings", enable_aria_label: true
    assert_current_path language_setup_path
    assert_select "user_native_language_id", selected: "English"
    assert_no_selector "#user_learning_language_id", visible: :all
  end

  test "모국어 목록에는 활성 언어만 이름순으로 표시된다" do
    click_link "Open language settings", enable_aria_label: true
    # 비활성 언어는 제외하고 빈 선택 안내를 뺀 실제 옵션의 순서까지 비교한다.
    expected = Language.enabled.order(:label).map { |language| [ language.id.to_s, language.label ] }
    options = all("#user_native_language_id option", visible: :all).reject { |option| option[:value].blank? }
    assert_equal expected, options.map { |option| [ option[:value], option.text(:all) ] }
  end

  test "모국어 변경은 이름과 이메일을 변경하지 않는다" do
    # 모국어 저장 이외의 프로필 데이터가 변경되지 않아야 한다.
    original_name, original_email = @user.display_name, @user.email_address
    click_link "Open language settings", enable_aria_label: true
    select "Korean", from: "user_native_language_id"
    click_button "Save changes"
    assert_current_path settings_path
    assert_equal languages(:korean), @user.reload.native_language
    assert_equal original_name, @user.display_name
    assert_equal original_email, @user.email_address
  end

  test "모국어가 없거나 비활성 언어이면 브라우저 검증을 우회해도 서버가 거부한다" do
    # 입력 제한을 직접 우회하여 서버에서도 모국어 검증이 유지되는지 확인한다.
    [ "", languages(:spanish).id.to_s ].each do |native_id|
      visit language_setup_path
      page.execute_script(<<~JS, native_id)
        const native = document.querySelector("#user_native_language_id");
        native.replaceChildren(new Option("Native", arguments[0], true, true));
        HTMLFormElement.prototype.submit.call(native.form);
      JS
      assert_selector '[role="alert"]', text: /\S/
      assert_equal languages(:english), @user.reload.native_language
    end
  end
end
