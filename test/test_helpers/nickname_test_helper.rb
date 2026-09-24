require "minitest/mock"

module NicknameTestHelper
  def with_stubbed_display_name(adjective: "Happy", noun: "Raccoon", &block)
    UserDisplayNameGenerator::ADJECTIVES.stub(:sample, adjective) do
      UserDisplayNameGenerator::NOUNS.stub(:sample, noun, &block)
    end
  end

  def create_nickname_user
    uid = SecureRandom.uuid
    OauthUserService.find_or_create(oauth_provider: :google, uid: uid, email: "#{uid}@example.com")
  end

  def expected_nickname_icon(noun)
    UserDisplayNameGenerator::ALL_IMAGE_PATHS_BY_NOUN.fetch(noun)
  end
end
