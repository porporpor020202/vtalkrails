require "test_helper"

class LanguageNavigationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:korean_native)
  end

  test "native language is required before entering the app" do
    @user.update!(native_language: nil)
    sign_in_as @user
    [root_path, rooms_path, settings_path, profile_path].each do |path|
      get path
      assert_redirected_to language_setup_path
    end
    assert_no_difference("VoiceDrop.count") { post voice_drop_path, as: :json }
    assert_response :forbidden
    get language_setup_path
    assert_response :success
    assert_select "select", count: 1
    assert_select "#bottom-tab-bar", count: 0
  end

  test "a valid native language completes onboarding including English" do
    @user.update!(native_language: nil)
    sign_in_as @user
    ["", Language.maximum(:id) + 1].each do |value|
      patch language_setup_path, params: { user: { native_language_id: value } }
      assert_response :unprocessable_entity
      assert_nil @user.reload.native_language_id
    end
    patch language_setup_path, params: { user: { native_language_id: languages(:english).id } }
    assert_redirected_to rooms_path
    assert @user.reload.language_setup_complete?
    follow_redirect!
    assert_select "h1", text: "Say"
    assert_select "#bottom-tab-bar a", count: 2
    assert_select "#bottom-tab-bar a", text: "Say"
    assert_select "#bottom-tab-bar a", text: "Setting"
  end

  test "Say shows conversations with different native languages without filtering" do
    other = User.create!(oauth_provider: :google, oauth_uid: "same-native",
      email_address: "same@example.com", native_language: languages(:korean))
    rooms = [users(:english_native), other].map { |user| Room.create!(user: @user, opponent: user) }
    sign_in_as @user
    get rooms_path
    rooms.each { |room| assert_select "a[href='#{room_path(room)}']" }
    assert_select "[data-voice-recorder-endpoint-value='#{voice_drop_path}']"
  end
end
