require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @english = Language.find_or_create_by!(code: "en") { |language| language.name = "English" }
    @korean = Language.find_or_create_by!(code: "ko") { |language| language.name = "Korean" }
  end

  test "language settings persist and display the saved selections" do
    user = users(:korean_native)
    other_user = users(:english_native)
    other_languages = other_user.attributes.slice("native_language_id")
    original_email = user.email_address
    sign_in_as user

    patch settings_path, params: { user: {
      native_language_id: @korean.id,
      email_address: "unwanted-change@example.com"
    } }

    assert_response :see_other
    assert_redirected_to settings_path
    assert_equal @korean, user.reload.native_language
    assert_equal original_email, user.email_address
    assert_equal other_languages, other_user.reload.attributes.slice("native_language_id")

    follow_redirect!
    assert_select "select[name='user[native_language_id]'] option[selected][value='#{@korean.id}']", text: "Korean"
    assert_select "[role='status']", text: "Language settings saved."
  end

  test "invalid languages show errors without partially saving either preference" do
    user = users(:korean_native)
    user.update!(native_language: @korean)
    sign_in_as user
    missing_id = Language.maximum(:id) + 1

    [ :native_language_id ].each do |attribute|
      values = { native_language_id: @english.id }
      patch settings_path, params: { user: values.merge(attribute => missing_id) }

      assert_response :unprocessable_entity
      assert_select "[role='alert']", text: /can't be blank/
      assert_equal @korean, user.reload.native_language
    end
  end

  test "language preferences cannot be cleared" do
    user = users(:korean_native)
    user.update!(native_language: @korean)
    sign_in_as user

    patch settings_path, params: { user: { native_language_id: "" } }

    assert_response :unprocessable_entity
    assert_equal @korean.id, user.reload.native_language_id
  end

  test "language updates require sign in" do
    user = users(:korean_native)
    original_languages = user.attributes.slice("native_language_id")

    patch settings_path, params: { user: { native_language_id: @korean.id } }

    assert_redirected_to new_session_path
    assert_equal original_languages, user.reload.attributes.slice("native_language_id")
  end

  test "language seeds update names without duplicating records" do
    original_ids = [@english.id, @korean.id]
    load Rails.root.join("db/seeds/01_languages.rb")
    @korean.update!(name: "한국어")

    assert_no_difference("Language.count") do
      2.times { load Rails.root.join("db/seeds/01_languages.rb") }
    end

    assert_equal "Korean", @korean.reload.name
    assert_equal "English", @english.reload.name
    assert_equal original_ids, [@english.id, @korean.id]
    assert_equal "Chinese (Mandarin)", Language.find_by!(code: "cmn").name
    assert_equal "Cantonese", Language.find_by!(code: "yue").name
    assert_equal "Other", Language.find_by!(code: "other").name
  end

  test "signed in user can access child safety reporting and standards" do
    sign_in_as users(:korean_native)

    get settings_path

    assert_response :success
    assert_select "a[href^='mailto:privacy@vtalks.net']", text: /Report a child safety concern/
    assert_select "a[href='#{child_safety_path}']", text: /Child Safety Standards/
  end
end
