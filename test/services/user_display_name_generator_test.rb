require "test_helper"

class UserDisplayNameGeneratorTest < ActiveSupport::TestCase
  test "provides more than one million readable combinations" do
    assert_operator UserDisplayNameGenerator.capacity, :>=, 1_000_000
  end

  test "maps an id to a stable animal name and icon" do
    first = UserDisplayNameGenerator.for_id(42)
    second = UserDisplayNameGenerator.for_id(42)

    assert_equal first.name, second.name
    assert_equal first.icon, second.icon
    assert_match(/\A\S+ \S+ .+\z/, first.name)
    assert first.icon.present?
  end

  test "new users receive unique generated names" do
    users = 12.times.map do |index|
      User.create!(email_address: "generated-#{index}@example.com", password: "password")
    end

    assert_equal users.length, users.map(&:name).uniq.length
    assert users.all? { |user| user.icon.present? }
  end

  test "every profile generates a bundled PNG instead of a Unicode icon" do
    UserDisplayNameGenerator::PROFILE_ICONS.each_with_index do |(_, path), index|
      assert_equal path, UserDisplayNameGenerator.for_id(index + 1).icon
      assert Rails.root.join("app/assets/images", path).file?, "Missing #{path}"
    end
  end

  test "existing Unicode profiles resolve to matching images without rewriting accounts" do
    assert_equal "emoji/animals_and_nature/raccoon_3d.png",
      UserDisplayNameGenerator.image_path_for("🦝")
    assert_equal "emoji/animals_and_nature/spider_3d.png",
      UserDisplayNameGenerator.image_path_for("🕷️")
    assert_equal "emoji/food_and_drink/lime_3d.png",
      UserDisplayNameGenerator.image_path_for("🍋‍🟩")
  end

  test "unknown icon values use a bundled fallback rather than arbitrary URLs" do
    [ nil, "", "https://example.com/tracking.png", "../../secret" ].each do |icon|
      assert_equal UserDisplayNameGenerator::IMAGE_PATHS.first,
        UserDisplayNameGenerator.image_path_for(icon)
    end
  end
end
