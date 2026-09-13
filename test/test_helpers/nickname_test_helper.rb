module NicknameTestHelper
  # Keep production arrays unchanged. Control Array#sample on test-only copies
  # so randomness can be verified without probabilistic assertions.
  def with_nickname_choices(adjective: "Happy", noun: "Raccoon")
    generator = UserDisplayNameGenerator
    originals = { ADJECTIVES: generator::ADJECTIVES, NOUNS: generator::NOUNS }
    calls = Hash.new(0)
    mutex = Mutex.new

    { ADJECTIVES: adjective, NOUNS: noun }.each do |constant, choice|
      raise ArgumentError, "Unknown choice: #{choice}" unless originals.fetch(constant).include?(choice)

      values = originals.fetch(constant).dup
      values.define_singleton_method(:sample) do |*args, **kwargs|
        mutex.synchronize { calls[constant] += 1 }
        choice
      end
      generator.send(:remove_const, constant)
      generator.const_set(constant, values.freeze)
    end

    yield calls
  ensure
    originals&.each do |constant, values|
      generator.send(:remove_const, constant)
      generator.const_set(constant, values)
    end
  end

  def create_nickname_user
    token = SecureRandom.uuid
    User.create!(oauth_provider: :google, oauth_uid: token, email_address: "#{token}@example.com")
  end

  def expected_nickname_icon(noun)
    UserDisplayNameGenerator::EMOJI_IMAGE_PATHS_BY_NOUN.fetch(noun)
  end
end
