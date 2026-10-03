require "test_helper"
require_relative "test_helpers/system_session_test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include SystemSessionTestHelper

  # driven_by :selenium, using: :chrome, screen_size: [1400, 1000]
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ] do |options|
    options.add_preference "intl.accept_languages", "en-US,en"
  end
end
