require "application_system_test_case"
require_relative "test_helpers/origins"

class RemoteOriginTestCase < ApplicationSystemTestCase
  setup do
    @previous_session_name = Capybara.session_name
    @previous_run_server = Capybara.run_server
    @previous_always_include_port = Capybara.always_include_port

    Capybara.session_name = :remote_origin
    Capybara.run_server = false
    Capybara.always_include_port = false
  end

  teardown do
    begin
      Capybara.current_session.reset!
    ensure
      Capybara.session_name = @previous_session_name
      Capybara.run_server = @previous_run_server
      Capybara.always_include_port = @previous_always_include_port
    end
  end
end
