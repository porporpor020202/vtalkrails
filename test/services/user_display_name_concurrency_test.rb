require "test_helper"
require "timeout"
require_relative "../test_helpers/nickname_test_helper"

class UserDisplayNameConcurrencyTest < ActiveSupport::TestCase
  include NicknameTestHelper

  self.use_transactional_tests = false
  self.fixture_table_names = []

  setup do
    clear_test_database
  end

  teardown do
    clear_test_database
  end

  # TODO: 일단 이 문제는 런칭에 도움이 안되니 skip. 우선순위가 너무 낮다. 동시성 문제는 다음에 풀자.
  test "동시에 같은 닉네임으로 가입해도 번호가 겹치지 않고 성공한다." do
    with_stubbed_display_name do
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

        names = User.where(id: worker_count.times.map { results.pop }).pluck(:display_name)
        assert_equal ["Happy Raccoon", "Happy Raccoon 2", "Happy Raccoon 3"], names.sort
      ensure
        threads.each { |thread| thread.kill if thread.alive? }
        threads.each(&:join)
      end
    end
  end

  private

  def clear_test_database
    connection = ActiveRecord::Base.connection
    database = connection.select_value("SELECT current_database()")
    raise "테스트 DB에서만 실행할 수 있습니다: #{database}" unless Rails.env.test? && database.match?(/_test(?:-\d+)?\z/)

    tables = connection.tables - ["schema_migrations", "ar_internal_metadata"]
    connection.truncate_tables(*tables) if tables.any?
    ActiveRecord::FixtureSet.reset_cache
  end
end
