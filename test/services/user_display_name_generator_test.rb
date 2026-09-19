require "test_helper"
require "minitest/mock"

class UserDisplayNameGeneratorTest < ActiveSupport::TestCase
  test "중복이 없을 때 기본 '형용사 명사' 형태로 생성된다" do
    UserDisplayNameGenerator::ADJECTIVES.stub(:sample, "Adventurous") do
      UserDisplayNameGenerator::NOUNS.stub(:sample, "Tiger") do
        name = UserDisplayNameGenerator.display_name
        assert_equal "Adventurous Tiger", name
      end
    end
  end

  # 2. 1번 중복될 때: '이름 2' 생성 테스트
  test "기본 이름이 이미 DB에 존재하면 숫자 2를 붙인다" do
    create_test_user(display_name: "Adventurous Tiger")

    UserDisplayNameGenerator::ADJECTIVES.stub(:sample, "Adventurous") do
      UserDisplayNameGenerator::NOUNS.stub(:sample, "Tiger") do
        name = UserDisplayNameGenerator.display_name
        assert_equal "Adventurous Tiger 2", name
      end
    end
  end

  # # 3. 연속 중복될 때: '이름 3' 생성 테스트
  # test "기본 이름과 2번 이름까지 존재하면 숫자 3을 붙인다" do
  #   create_test_user(display_name: "Adventurous Tiger")
  #   create_test_user(display_name: "Adventurous Tiger 2")
  #
  #   UserDisplayNameGenerator::ADJECTIVES.stub(:sample, "Adventurous") do
  #     UserDisplayNameGenerator::NOUNS.stub(:sample, "Tiger") do
  #       name = UserDisplayNameGenerator.display_name
  #       assert_equal "Adventurous Tiger 3", name
  #     end
  #   end
  # end
  #
  # private
  #
  # # 테스트용 유저를 DB에 생성하는 헬퍼 메서드
  # # (앞서 설정했던 null: false 필드들을 채워주기 위함)
  # def create_test_user(display_name:)
  #   User.create!(
  #     display_name: display_name,
  #     oauth_provider: "google",
  #     oauth_uid: SecureRandom.hex(8),
  #     email_address: "#{SecureRandom.hex(4)}@example.com",
  #     icon: "emoji/animals_and_nature/tiger_face_3d.png"
  #   )
  # end
end
