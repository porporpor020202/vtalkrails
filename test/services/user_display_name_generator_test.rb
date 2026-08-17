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
end
