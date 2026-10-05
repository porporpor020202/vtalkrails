require "test_helper"

class UserActivityTest < ActionDispatch::IntegrationTest
  test "r_로그인한 사용자가 앱에 접속하면 최근 접속 시각을 갱신한다" do
    user = users(:english_native)
    other = users(:korean_native)
    sign_in_as(user)

    freeze_time do
      previous_activity = 1.week.ago
      user.update!(last_active_at: previous_activity)
      other.update!(last_active_at: previous_activity)

      get rooms_path

      assert_response :success
      assert_equal Time.current, user.reload.last_active_at
      assert_equal previous_activity, other.reload.last_active_at
    end
  end
end
