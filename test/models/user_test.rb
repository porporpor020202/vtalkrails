require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "모국어만 있는 사용자는 나이 확인과 완료 기록이 있으면 온보딩 완료 상태다" do
    # 학습 언어는 온보딩 완료 판단에 사용하지 않는다.
    user = users(:english_native)
    assert_nil user.attributes["learning_language_id"]
    assert user.onboarding_complete?
    user.age_confirmed_at = nil
    assert_not user.onboarding_complete?
  end

  test "닉네임의 명사에 맞는 이미지 경로를 반환한다" do
    {
      "Happy Raccoon" => "emoji/animals_and_nature/raccoon_3d.png",
      "Happy Raccoon 2" => "emoji/animals_and_nature/raccoon_3d.png",
      "Calm Polar Bear" => "emoji/animals_and_nature/polar_bear_3d.png",
      "Calm Polar Bear 12" => "emoji/animals_and_nature/polar_bear_3d.png",
      "Happy Rice Ball 3" => "emoji/food_and_drink/rice_ball_3d.png"
    }.each do |display_name, expected_path|
      user = User.new(display_name: display_name)

      assert_equal expected_path, user.profile_image_path_for, display_name
      assert Rails.root.join("app/assets/images", user.profile_image_path_for).file?,
        "Image file is missing: #{user.profile_image_path_for}"
    end
  end
end
