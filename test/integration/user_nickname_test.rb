require "test_helper"
require_relative "../test_helpers/nickname_test_helper"

class UserNicknameTest < ActionDispatch::IntegrationTest
  include NicknameTestHelper

  teardown { Current.reset }

  test "07 처음 가입하면 닉네임과 명사에 맞는 이미지가 자동 저장된다" do
    with_nickname_choices do
      [:google, :apple].each_with_index do |provider, index|
        token = SecureRandom.uuid
        user = nil
        assert_difference("User.count", 1) do
          user = OauthUserService.find_or_create(oauth_provider: provider, uid: token, email: "#{token}@example.com")
        end

        assert user.persisted?
        assert_equal(index.zero? ? "Happy Raccoon" : "Happy Raccoon 2", user.reload.name)
        assert_equal expected_nickname_icon("Raccoon"), user.icon
      end
    end
  end

  test "08 재로그인과 새 요청 및 DB 재조회 후에도 닉네임과 이미지가 유지된다" do
    user = with_nickname_choices { create_nickname_user }
    original = user.reload.attributes.slice("name", "icon")
    assert original.values.all?(&:present?)
    login_nickname_user(user)
    get mypage_path
    assert_response :success
    delete session_path
    assert_redirected_to new_session_path
    reset!
    Current.reset

    # A different random choice must not change an existing account's identity.
    with_nickname_choices(adjective: "Calm", noun: "Tiger") do
      returning_user = nil
      assert_no_difference("User.count") do
        returning_user = OauthUserService.find_or_create(
          oauth_provider: :google, uid: user.oauth_uid, email: user.email_address
        )
      end
      login_nickname_user(returning_user)
      Current.reset
      get mypage_path
      assert_response :success
      assert_select "h2", text: original.fetch("name")
      assert_equal original, User.find(user.id).attributes.slice("name", "icon")
    end
  end

  test "09 닉네임과 같은 프로필 영역에 해당 명사의 이미지가 표시된다" do
    ["Raccoon", "Polar Bear"].each do |noun|
      user = with_nickname_choices(noun: noun) { create_nickname_user }
      assert_equal "Happy #{noun}", user.name
      assert_nickname_profile(user, noun)
      reset!
      Current.reset
    end
  end

  test "10 번호가 붙은 닉네임에도 같은 명사의 이미지가 표시된다" do
    user = with_nickname_choices do
      3.times { create_nickname_user }
      create_nickname_user
    end

    assert_equal "Happy Raccoon 4", user.reload.name
    assert_nickname_profile(user, "Raccoon")
  end

  private

  def login_nickname_user(user)
    Current.reset
    get authenticate_by_token_google_oauth_sessions_path,
      params: { token: user.signed_id(purpose: :native_auth, expires_in: 5.minutes) }
    assert_redirected_to root_path
  end

  def assert_nickname_profile(user, noun)
    path = expected_nickname_icon(noun)
    assert_equal path, user.reload.icon
    assert Rails.root.join("app/assets/images", path).file?, "이미지 파일이 없습니다: #{path}"
    login_nickname_user(user)
    get mypage_path
    assert_response :success
    assert_select "h2", text: user.name, count: 1 do |headings|
      profile = headings.first.parent.parent
      images = profile.css("img")
      assert_equal 1, images.length
      assert_equal ActionController::Base.helpers.image_path(path), images.first["src"]
      assert_operator images.first["width"].to_i, :>, 0
      assert_operator images.first["height"].to_i, :>, 0
    end
  end
end
