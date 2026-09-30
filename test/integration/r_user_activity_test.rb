require "test_helper"

class UserActivityTest < ActionDispatch::IntegrationTest
  teardown { Current.reset }

  test "r_웹과 앱 세션의 최근 활동을 사용자에 모으고 5분 간격으로 갱신한다" do
    user = users(:korean_native)
    user.update_columns(last_active_at: nil)
    now = Time.current.change(usec: 0)

    travel_to now do
      sign_in_as user
      get rooms_path
      assert_response :success
      assert_equal now, user.reload.last_active_at
    end

    travel_to now + 1.minute do
      reset!
      Current.reset
      sign_in_as user
      get rooms_path, headers: { "User-Agent" => "vtalk/ios/1.0" }
      assert_response :success
      assert_equal now, user.reload.last_active_at
    end

    travel_to now + 5.minutes do
      get rooms_path, headers: { "User-Agent" => "vtalk/ios/1.0" }
      assert_response :success
      assert_equal now + 5.minutes, user.reload.last_active_at
    end
  end

  test "r_비로그인 요청은 사용자 활동을 갱신하지 않는다" do
    Current.reset
    before = User.order(:id).pluck(:id, :last_active_at)

    get rooms_path

    assert_redirected_to new_session_path
    assert_equal before, User.order(:id).pluck(:id, :last_active_at)
  end
end
