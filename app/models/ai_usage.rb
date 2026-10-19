require "openssl"

# Free training days and daily AI responses share the same persistent identity.
class AiUsage < ApplicationRecord
  FREE_DAYS = 3
  DAILY_HELP_LIMIT = 1
  ANONYMOUS_IP_LIMIT = 3
  HELP_MODES = %w[question example answer].freeze
  LOCK_KEY = 7_316_248_901
  class TrialExpired < StandardError; end
  class LoginRequired < StandardError; end
  class DailyLimitExceeded < StandardError
    attr_reader :response
    def initialize(response: nil)
      @response = response
      super("Daily AI help already used")
    end
  end

  belongs_to :merged_into, class_name: "AiUsage", optional: true

  def self.start_day!(user:, visitor_id:, date: Date.current)
    synchronize do
      usage = budget_for(user: user, visitor_id: visitor_id)
      raise LoginRequired if !user && usage.merged_into_id.present?

      days = usage.training_dates
      raise TrialExpired unless usage.available_on?(date)
      usage.update!(training_dates: (days + [ date ]).uniq.sort)
      reset_help_day!(usage, date)
      usage
    end
  end

  def self.fetch!(usage:, mode:, input:, ip: nil, date: Date.current)
    raise ArgumentError, "Unsupported AI help" unless HELP_MODES.include?(mode)
    digest = identity("input", input)
    cached = nil
    synchronize do
      usage.reload
      usage = usage.merged_into if usage.merged_into_id.present?
      reset_help_day!(usage, date)
      slot = usage.help_data.fetch(mode, {})
      if slot["response"].present? && slot["input_digest"] == digest
        cached = slot["response"]
        next
      end
      raise DailyLimitExceeded.new(response: slot["response"]) if slot.fetch("attempts", 0) >= DAILY_HELP_LIMIT

      if ip
        network = find_or_create_by!(identity_key: identity("ip", ip))
        reset_help_day!(network, date)
        attempts = network.help_data.dig(mode, "attempts").to_i
        raise DailyLimitExceeded if attempts >= ANONYMOUS_IP_LIMIT
        network.update!(help_data: network.help_data.merge(mode => { "attempts" => attempts + 1 }))
      end
      usage.update!(help_data: usage.help_data.merge(mode => { "attempts" => 1, "input_digest" => digest }))
    end
    return cached if cached

    # Reserve before the paid call. Keep failed attempts charged to prevent loops.
    response = yield
    synchronize do
      usage.reload
      usage = usage.merged_into if usage.merged_into_id.present?
      slot = usage.help_data.fetch(mode, {})
      if usage.help_on == date && slot["input_digest"] == digest
        usage.update!(help_data: usage.help_data.merge(mode => slot.merge("response" => response)))
      end
    end
    response
  end

  def self.claim!(user:, visitor_id:)
    synchronize { budget_for(user: user, visitor_id: visitor_id) }
  end

  def available_on?(date)
    training_dates.include?(date) || training_dates.size < FREE_DAYS
  end

  def self.clear_user_responses!(user)
    where(identity_key: identity("user", "#{user.oauth_provider}:#{user.oauth_uid}")).update_all(help_data: {}, help_on: nil)
  end

  def self.clear_old_responses!
    where("help_on < ?", Date.current).where.not(help_data: {}).update_all(help_data: {})
  end

  def self.synchronize
    transaction do
      connection_pool.with_connection { |database| database.execute("SELECT pg_advisory_xact_lock(#{LOCK_KEY})") }
      yield
    end
  end
  private_class_method :synchronize

  def self.reset_help_day!(usage, date)
    usage.update!(help_on: date, help_data: {}) if usage.help_on != date
  end
  private_class_method :reset_help_day!

  def self.budget_for(user:, visitor_id:)
    guest = find_or_create_by!(identity_key: identity("guest", visitor_id)) if visitor_id.present?
    return guest || raise(ArgumentError, "Missing visitor identity") unless user

    account = find_or_create_by!(identity_key: identity("user", "#{user.oauth_provider}:#{user.oauth_uid}"))
    saved_dates = user.daily_practices.where("practiced_on <= ?", Date.current).distinct.pluck(:practiced_on)
    dates = account.training_dates | saved_dates
    if guest && guest.merged_into_id.nil?
      dates |= guest.training_dates
      if guest.help_on == Date.current
        reset_help_day!(account, Date.current)
        help = guest.help_data.merge(account.help_data)
        account.update!(help_data: help)
      end
    end
    # A new guest cookie must not extend an account's exhausted trial at login.
    dates = dates.sort.first(FREE_DAYS)
    account.update!(training_dates: dates) if dates != account.training_dates
    # A shared browser switching accounts must never copy the previous account's responses.
    guest&.update!(merged_into: account, help_data: {}) if guest && guest.merged_into_id != account.id
    account
  end
  private_class_method :budget_for

  def self.identity(scope, value)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "ai-usage:#{scope}:#{value}")
  end
  private_class_method :identity
end
