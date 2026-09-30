require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "r_닉네임의 명사에 맞는 이미지 경로를 반환한다" do
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
        "이미지 파일이 없습니다: #{user.profile_image_path_for}"
    end
  end
end
