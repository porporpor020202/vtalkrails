require "application_system_test_case"

class LanguageSettingsTest < ApplicationSystemTestCase
  setup do
    @user = users(:english_native)
    sign_in(user: @user)
    visit settings_path
  end

  test "r_설정 페이지에 학습 언어와 모국어가 표시된다" do
    within find_link("Open language settings", enable_aria_label: true) do
      assert_text "Learning language"
      assert_text @user.learning_language.label

      assert_text "Native language"
      assert_text @user.native_language.label
    end
  end

  test "r_언어 카드를 누르면 편집 화면이 열린다" do
    click_link "Open language settings", enable_aria_label: true

    assert_current_path language_setup_path
    assert_select "user_learning_language_id", selected: @user.learning_language.label
    assert_select "user_native_language_id", selected: @user.native_language.label
  end

  test "r_두 언어 목록에는 활성 언어만 이름순으로 표시된다" do
    click_link "Open language settings", enable_aria_label: true

    expected = Language.enabled.order(:label).map do |language|
      [ language.id.to_s, language.label ]
    end

    %w[user_native_language_id user_learning_language_id].each do |id|
      options = all("##{id} option", visible: :all).reject { |option| option[:value].blank? }

      assert_equal expected, options.map { |option| [ option[:value], option.text(:all) ] }
    end
  end

  test "r_모국어와 같은 언어는 학습 언어에서 선택할 수 없다" do
    click_link "Open language settings", enable_aria_label: true

    option = find(
      "#user_learning_language_id option[value='#{@user.native_language_id}']",
      visible: :all
    )

    assert option.disabled?
  end

  test "r_모국어를 현재 학습 언어로 바꾸면 학습 언어 선택을 초기화한다" do
    click_link "Open language settings", enable_aria_label: true


    assert_select "user_native_language_id", selected: "English"
    select "Korean", from: "user_native_language_id"

    assert_equal "", find("#user_learning_language_id").value
    assert find(
      "#user_learning_language_id option[value='#{languages(:korean).id}']",
      visible: :all
    ).disabled?

    select "English", from: "user_learning_language_id"
    assert_select "user_learning_language_id", selected: "English"
  end

  test "r_변경한 언어를 저장하면 설정에 반영되고 다시 열어도 유지된다" do
    # 영어가 모국어인 사용자임.

    original_name = @user.display_name
    original_email = @user.email_address

    click_link "Open language settings", enable_aria_label: true

    assert_select "user_native_language_id", selected: @user.native_language.label
    assert_select "user_learning_language_id", selected: @user.learning_language.label

    select "Korean", from: "user_native_language_id"
    select "English", from: "user_learning_language_id"

    # 선택만 바꿨을 때는 DB에 저장되지 않는다.
    @user.reload
    assert_equal languages(:english), @user.native_language
    assert_equal languages(:korean), @user.learning_language

    assert_button "Save changes", disabled: false
    click_button "Save changes"

    assert_current_path settings_path

    # 저장 버튼을 누른 후에 DB에 반영된다.
    @user.reload
    assert_equal languages(:korean), @user.native_language
    assert_equal languages(:english), @user.learning_language
    assert_equal original_name, @user.display_name
    assert_equal original_email, @user.email_address

    within find_link("Open language settings", enable_aria_label: true) do
      assert_text "Korean"
      assert_text "English"
    end

    click_link "Open language settings", enable_aria_label: true

    assert_select "user_native_language_id", selected: "Korean"
    assert_select "user_learning_language_id", selected: "English"
  end

  test "r_언어 중 하나가 비어 있으면 저장하지 않고 선택 안내 dialog를 표시한다" do
    [
      [ "user_native_language_id", "Select your native language" ],
      [ "user_learning_language_id", "Select your learning language" ]
    ].each do |field, prompt|
      visit language_setup_path

      assert_select "user_native_language_id", selected: @user.native_language.label
      assert_select "user_learning_language_id", selected: @user.learning_language.label

      assert_no_selector "dialog[open]"
      select prompt, from: field
      click_button "Save changes"

      within "dialog[open]" do
        assert_text "Please select both your native language and learning language."
        click_button "OK"
      end

      assert_no_selector "dialog[open]"
      assert_current_path language_setup_path
      assert_equal "", find("##{field}").value

      @user.reload
      assert_equal languages(:english), @user.native_language
      assert_equal languages(:korean), @user.learning_language
    end
  end

  test "r_언어를 선택하지 않으면 저장하지 않고 안내 dialog를 표시한다" do
    [
      [ "user_native_language_id", "Select your native language" ],
      [ "user_learning_language_id", "Select your learning language" ]
    ].each do |field, prompt|
      visit settings_path
      click_link "Open language settings", enable_aria_label: true

      assert_no_selector "dialog[open]"

      select prompt, from: field
      click_button "Save changes"

      within "dialog[open]" do
        assert_text "Please select both your native language and learning language."
        click_button "OK"
      end

      assert_no_selector "dialog[open]"
      assert_current_path language_setup_path
      assert_equal "", find("##{field}").value

      @user.reload
      assert_equal languages(:english), @user.native_language
      assert_equal languages(:korean), @user.learning_language
    end
  end

  test "언어 설정이 유효하지 않으면 브라우저 제한을 우회해도 서버가 저장을 거부한다" do
    [
      [ "Native language is missing", nil, :korean ],
      [ "Learning language is missing", :english, nil ],
      [ "Native language is disabled", :spanish, :korean ],
      [ "Learning language is disabled", :english, :spanish ],
      [ "Both languages are the same", :english, :english ]
    ].each do |description, native, learning|
      visit settings_path
      click_link "Open language settings", enable_aria_label: true

      native_id = native ? languages(native).id.to_s : ""
      learning_id = learning ? languages(learning).id.to_s : ""

      assert_selector "#user_native_language_id"
      assert_selector "#user_learning_language_id"

      # 클라이언트 검증을 우회하고 실제 폼을 서버에 제출한다.
      page.execute_script(<<~JS, native_id, learning_id)
        const native = document.querySelector("#user_native_language_id");
        const learning = document.querySelector("#user_learning_language_id");

        native.replaceChildren(new Option("Native", arguments[0], true, true));
        learning.replaceChildren(new Option("Learning", arguments[1], true, true));

        HTMLFormElement.prototype.submit.call(native.form);
      JS

      assert_selector '[role="alert"]', text: /\S/

      @user.reload
      assert_equal languages(:english), @user.native_language, description
      assert_equal languages(:korean), @user.learning_language, description
    end
  end
end
