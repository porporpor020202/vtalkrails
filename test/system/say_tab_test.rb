require "application_system_test_case"

class SayTabTest < ApplicationSystemTestCase
  setup do
    @previous_session_name = Capybara.session_name
    Capybara.session_name = :local_say_tab
    Current.reset

    sign_in(user: users(:english_native))
    within "#bottom-tab-bar" do
      click_link "Say"
    end
    assert_current_path rooms_path
  end

  teardown do
    Capybara.current_session.reset!
    Capybara.session_name = @previous_session_name
    Current.reset
  end

  test "r_Say 탭의 언어 목록에는 학습 언어와 모국어가 순서대로 표시된다" do
    user = users(:english_native)
    expected_languages = [ user.learning_language, user.native_language ]

    within "header" do
      assert_selector "#say_language_id option", count: 2, visible: :all
      options = all("#say_language_id option", visible: :all)

      # TODO: &:label 공식문서 확인하자.
      assert_equal expected_languages.map(&:label), options.map { |option| option.text(:all) }
      assert_equal expected_languages.map { |language| language.id.to_s }, options.map { |option| option[:value] }
      assert_select "say_language_id", selected: user.learning_language.label
    end
  end
end
