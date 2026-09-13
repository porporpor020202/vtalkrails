require "test_helper"
require_relative "../test_helpers/nickname_test_helper"

class UserDisplayNameGeneratorTest < ActiveSupport::TestCase
  include NicknameTestHelper

  test "01 형용사와 명사를 각각 랜덤 선택하여 닉네임을 만든다" do
    [["Happy", "Raccoon"], ["Calm", "Polar Bear"]].each do |adjective, noun|
      with_nickname_choices(adjective: adjective, noun: noun) do |calls|
        user = create_nickname_user

        assert_equal "#{adjective} #{noun}", user.reload.name
        assert_operator calls[:ADJECTIVES], :>=, 1, "형용사를 랜덤 선택해야 한다"
        assert_operator calls[:NOUNS], :>=, 1, "명사를 랜덤 선택해야 한다"
      end
    end
  end

  test "02 처음 지급하는 조합에는 숫자를 붙이지 않는다" do
    with_nickname_choices do
      assert_equal "Happy Raccoon", create_nickname_user.reload.name
    end
  end

  test "03 같은 조합을 지급할 때마다 2부터 번호를 증가시킨다" do
    with_nickname_choices do
      names = 4.times.map { create_nickname_user.reload.name }

      assert_equal ["Happy Raccoon", "Happy Raccoon 2", "Happy Raccoon 3", "Happy Raccoon 4"], names
    end
  end

  test "04 중복 번호가 붙어도 처음 선택한 형용사와 명사를 유지한다" do
    with_nickname_choices(adjective: "Calm", noun: "Polar Bear") do
      create_nickname_user
      assert_equal "Calm Polar Bear 2", create_nickname_user.reload.name
      assert_equal "Calm Polar Bear 3", create_nickname_user.reload.name
    end
  end

  test "05 탈퇴한 기본 이름과 중간 번호와 마지막 번호를 재사용하지 않는다" do
    with_nickname_choices do
      users = 3.times.map { create_nickname_user }
      assert_equal ["Happy Raccoon", "Happy Raccoon 2", "Happy Raccoon 3"], users.map(&:name)
      users[1].destroy!
      users[2].destroy!

      fourth = create_nickname_user
      assert_equal "Happy Raccoon 4", fourth.reload.name

      users.first.destroy!
      fourth.destroy!
      assert_equal "Happy Raccoon 5", create_nickname_user.reload.name
    end
  end
end
