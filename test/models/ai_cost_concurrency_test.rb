require "test_helper"
require "minitest/mock"
require_relative "../test_helpers/daily_practice_test_helper"

class AiCostConcurrencyTest < ActiveSupport::TestCase
  include DailyPracticeTestHelper
  self.use_transactional_tests = false

  test "concurrent requests reserve one training day and only one paid answer" do
    visitor = SecureRandom.uuid
    ip = "test-network-#{SecureRandom.uuid}"
    keys = [ AiUsage.send(:identity, "guest", visitor), AiUsage.send(:identity, "ip", ip) ]
    gate = Queue.new
    calls = 0
    lock = Mutex.new
    threads = 6.times.map do
      Thread.new do
        gate.pop
        ActiveRecord::Base.connection_pool.with_connection(prevent_permanent_checkout: true) do
          usage = AiUsage.start_day!(user: nil, visitor_id: visitor)
          AiUsage.fetch!(usage: usage, mode: "answer", input: "hello", ip: ip) do
            lock.synchronize { calls += 1 }
            sleep 0.05
            { "english" => "Hello.", "ipa" => "/həˈloʊ/" }
          end
          :allowed
        rescue AiUsage::DailyLimitExceeded
          :blocked
        end
      end
    end
    6.times { gate << true }
    results = threads.map(&:value)
    assert_includes results, :allowed
    assert_equal 6, results.count(:allowed) + results.count(:blocked)
    assert_equal 1, calls
    usage = AiUsage.find_by!(identity_key: keys.first)
    assert_equal [ Date.current ], usage.training_dates
    assert_equal "Hello.", AiUsage.fetch!(usage: usage, mode: "answer", input: "hello", ip: ip) { raise "Must replay the saved response" }.fetch("english")
  ensure
    threads&.each(&:join)
    AiUsage.where(identity_key: keys).delete_all
  end

  test "simultaneous first visits pay for the shared daily question only once" do
    date = Date.new(2099, 1, 1)
    DailyQuestion.where(asked_on: date).delete_all
    calls = 0
    lock = Mutex.new
    generator = Object.new
    generator.define_singleton_method(:call) do |date:|
      lock.synchronize { calls += 1 }
      sleep 0.05
      "What made you smile today?"
    end
    threads = []
    GeminiQuestion.stub(:new, -> { generator }) do
      threads = 4.times.map do
        Thread.new { ActiveRecord::Base.connection_pool.with_connection(prevent_permanent_checkout: true) { DailyQuestion.for_date(date).id } }
      end
      ids = threads.map(&:value)
      assert_equal 1, ids.uniq.size
      assert_equal 1, calls
    end
  ensure
    threads&.each(&:join)
    DailyQuestion.where(asked_on: date).delete_all
  end

  test "simultaneous shares create one reward per person and pay for one shared bonus question" do
    date = Date.new(2099, 1, 2)
    practices = [ users(:korean_native), users(:spanish_native) ].map { |user| complete_practice(user, date) }
    gate = Queue.new
    calls = 0
    lock = Mutex.new
    generator = Object.new
    generator.define_singleton_method(:call) do |**|
      lock.synchronize { calls += 1 }
      sleep 0.05
      "What is your favorite color?"
    end
    threads = []
    GeminiQuestion.stub(:new, -> { generator }) do
      threads = 6.times.map do |index|
        Thread.new do
          gate.pop
          ActiveRecord::Base.connection_pool.with_connection(prevent_permanent_checkout: true) do
            BonusPractice.unlock_for!(DailyPractice.find(practices[index % 2].id)).id
          end
        end
      end
      6.times { gate << true }
      assert_equal 2, threads.map(&:value).uniq.size
      assert_equal 1, calls
      assert_equal 1, BonusPractice.where(daily_practice: practices).distinct.count(:question)
    end
  ensure
    threads&.each(&:join)
    practices&.each(&:destroy!)
    DailyQuestion.where(asked_on: date).delete_all
  end
end
