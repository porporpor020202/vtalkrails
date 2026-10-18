require "test_helper"
require "minitest/mock"

class GeminiTranslationTest < ActiveSupport::TestCase
  test "answer parses English and IPA and rejects missing IPA" do
    client = Object.new
    client.define_singleton_method(:call) { |**| { english: "I like coffee.", ipa: "/aɪ laɪk ˈkɔfi/" }.to_json }
    GeminiText.stub(:new, -> { client }) do
      assert_equal "I like coffee.", GeminiTranslation.new.call(text: "커피를 좋아해요.", mode: "answer")["english"]
    end
    client.define_singleton_method(:call) { |**| '{"english":"Coffee"}' }
    GeminiText.stub(:new, -> { client }) do
      assert_raises(GeminiText::Unavailable) { GeminiTranslation.new.call(text: "커피", mode: "answer") }
    end
  end
end
