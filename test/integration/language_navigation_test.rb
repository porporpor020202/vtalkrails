require "test_helper"

class LanguageNavigationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:english_speaker)
    @english = languages(:english)
    @korean = languages(:korean)
  end

  test "both login providers send incomplete users to language setup" do
    @user.update!(mother_language: nil, learning_language: nil)
    [authenticate_by_token_google_oauth_sessions_path, authenticate_by_token_apple_oauth_sessions_path].each do |path|
      get path, params: { token: @user.signed_id(purpose: :native_auth, expires_in: 5.minutes) }
      assert_redirected_to language_setup_path
      follow_redirect!
      assert_select "h1", text: "Choose your languages"
      assert_select "#bottom-tab-bar", count: 0
      delete session_path
    end
  end

  test "incomplete users cannot bypass setup but can access support and sign out" do
    @user.update!(mother_language: nil, learning_language: nil)
    sign_in_as @user
    [root_path, rooms_path(tab: "mother"), settings_path, profile_path].each do |path|
      get path
      assert_redirected_to language_setup_path
    end
    assert_no_difference("Room.count") do
      post voice_drop_path(tab: "learning"), as: :json
    end
    assert_response :forbidden
    assert_equal language_setup_path, response.parsed_body["redirect_url"]
    get support_path
    assert_response :success
    delete session_path
    assert_redirected_to new_session_path
  end

  test "setup rejects missing identical and unknown languages then admits a valid selection" do
    @user.update!(mother_language: nil, learning_language: nil)
    sign_in_as @user
    [
      { mother_language_id: "", learning_language_id: @english.id },
      { mother_language_id: @korean.id, learning_language_id: "" },
      { mother_language_id: @english.id, learning_language_id: @english.id },
      { mother_language_id: @korean.id, learning_language_id: Language.maximum(:id) + 1 }
    ].each do |attributes|
      patch language_setup_path, params: { user: attributes }
      assert_response :unprocessable_entity
      assert_select "[role='alert']"
      assert_not @user.reload.language_setup_complete?
    end
    patch language_setup_path, params: { user: { mother_language_id: @korean.id, learning_language_id: @english.id } }
    assert_redirected_to rooms_path(tab: "learning")
    assert @user.reload.language_setup_complete?
    follow_redirect!
    assert_response :success
    assert_select "#bottom-tab-bar a", count: 3
    get language_setup_path
    assert_redirected_to rooms_path(tab: "learning")
  end

  test "settings cannot save the same language twice" do
    sign_in_as @user
    patch settings_path, params: { user: { mother_language_id: @english.id, learning_language_id: @english.id } }
    assert_response :unprocessable_entity
    assert_select "[role='alert']", text: /must be different/
    assert_equal @korean.id, @user.reload.mother_language_id
  end

  test "each tab filters by the current user language and preserves the tab through a room" do
    english_room = Room.create!(user: @user, opponent: users(:korean_learner), language: @english)
    korean_room = Room.create!(user: @user, opponent: users(:korean_learner), language: @korean)
    outsider = User.create!(email_address: "outsider@example.com", oauth_provider: :google, oauth_uid: "outsider")
    private_room = Room.create!(user: outsider, opponent: users(:korean_learner), language: @english)
    sign_in_as @user

    { "learning" => [english_room, korean_room], "mother" => [korean_room, english_room] }.each do |tab, (visible, hidden)|
      get rooms_path(tab: tab)
      assert_response :success
      assert_select "a[href='#{room_path(visible, tab: tab)}']", count: 1
      assert_select "a[href^='#{room_path(hidden)}']", count: 0
      assert_select "a[href^='#{room_path(private_room)}']", count: 0
      assert_select "[data-voice-recorder-endpoint-value='#{voice_drop_path(tab: tab)}']"
      get room_path(visible, tab: tab)
      assert_select "a[href='#{rooms_path(tab: tab)}'][aria-label='Back to rooms']"
    end
    delete room_path(korean_room, tab: "mother")
    assert_redirected_to rooms_path(tab: "mother")
  end

  test "new voice drops use the selected tab language" do
    sign_in_as @user
    assert_difference("Room.count", 1) do
      post voice_drop_path(tab: "mother"), params: { request_key: SecureRandom.uuid, voice_message: {
        audio: fixture_file_upload("sample.webm", "audio/webm"), duration_ms: 1000
      } }
    end
    assert_response :created
    room = Room.order(:id).last
    assert_equal @korean.id, room.language_id
    assert_equal rooms_path(tab: "mother"), response.parsed_body["redirect_url"]
    assert_equal 1, response.parsed_body["recipient_count"]
  end
end
