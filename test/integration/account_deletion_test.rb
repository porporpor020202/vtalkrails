require "test_helper"
require_relative "../test_helpers/voice_test_helper"

class AccountDeletionIntegrationTest < ActionDispatch::IntegrationTest
  include VoiceTestHelper
  include ActiveJob::TestHelper

  test "r_로그인하지 않은 사용자의 계정 삭제 요청은 거부한다" do
    # 인증하지 않은 DELETE 요청으로 임의 계정이 삭제되지 않아야 한다.
    assert_no_difference "User.count" do
      delete account_path
    end

    assert_redirected_to new_session_path
  end
end
