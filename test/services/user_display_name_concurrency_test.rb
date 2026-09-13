require "test_helper"
require "timeout"
require_relative "../test_helpers/nickname_test_helper"

class UserDisplayNameConcurrencyTest < ActiveSupport::TestCase
  include NicknameTestHelper

  # Real commits and separate connections are required to test competing signups.
  self.use_transactional_tests = false
  self.fixture_table_names = []

  setup { clear_nickname_test_database }
  teardown { clear_nickname_test_database }

  test "06 동시에 같은 조합으로 가입해도 모두 성공하고 번호가 겹치지 않는다" do
    with_nickname_choices do
      ready = Queue.new
      start = Queue.new
      results = Queue.new
      failures = Queue.new
      connections = Queue.new
      threads = []
      worker_count = 3
      pool = ActiveRecord::Base.connection_pool
      assert_operator pool.size, :>=, worker_count
      pool.release_connection

      begin
        threads = worker_count.times.map do
          Thread.new do
            pool.with_connection do |connection|
              connections << connection.select_value("SELECT pg_backend_pid()")
              ready << true
              start.pop
              results << create_nickname_user.id
            end
          rescue StandardError => error
            failures << "#{error.class}: #{error.message}"
          end
        end

        Timeout.timeout(15) { worker_count.times { ready.pop } }
        worker_count.times { start << true }
        Timeout.timeout(30) { threads.each(&:join) }

        errors = []
        errors << failures.pop until failures.empty?
        assert_empty errors, "모든 동시 가입이 성공해야 한다: #{errors.join('; ')}"
        assert_equal worker_count, connections.size
        assert_equal worker_count, worker_count.times.map { connections.pop }.uniq.size
        assert_equal worker_count, results.size

        names = User.where(id: worker_count.times.map { results.pop }).pluck(:name)
        assert_equal ["Happy Raccoon", "Happy Raccoon 2", "Happy Raccoon 3"], names.sort
      ensure
        threads.each { |thread| thread.kill if thread.alive? }
        threads.each(&:join)
      end
    end
  end

  private

  def clear_nickname_test_database
    connection = ActiveRecord::Base.connection
    database = connection.select_value("SELECT current_database()")
    raise "테스트 DB에서만 실행할 수 있습니다: #{database}" unless Rails.env.test? && database.match?(/_test(?:-\d+)?\z/)

    # Also clear future allocation history tables, so retired numbers from a
    # previous run cannot affect this test. Preserve Rails schema metadata.
    tables = connection.tables - ["schema_migrations", "ar_internal_metadata"]
    connection.truncate_tables(*tables) if tables.any?
    ActiveRecord::FixtureSet.reset_cache
  end
end
