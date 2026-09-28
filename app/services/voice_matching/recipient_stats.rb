module VoiceMatching
  class RecipientStats
    def initialize(users, now: Time.current, config: Rails.application.config_for(:voice_matching))
      @users, @now, @config = users, now, config
    end

    def call
      ids = @users.map(&:id)
      return {} if ids.empty?

      active = Room.where.not(status: :deleted)
      pending_as_user = active.where(user_id: ids).where("last_sender_id = opponent_id").group(:user_id).count
      pending_as_opponent = active.where(opponent_id: ids).where("last_sender_id = user_id").group(:opponent_id).count
      deliveries = VoiceDelivery.where(recipient_id: ids)
      exposure = deliveries.where("created_at >= ?", @now - 24.hours).group(:recipient_id).count
      window = @config.fetch(:response_window_hours).hours
      mature = deliveries.where(created_at: (@now - @config.fetch(:history_days).days)..(@now - window))
      received = mature.group(:recipient_id).count
      replied = mature.where("first_replied_at <= created_at + make_interval(secs => ?)", window.to_i).group(:recipient_id).count
      hours = UserActivityHour.where(user_id: ids).where("updated_at >= ?", @now - @config.fetch(:history_days).days)
        .pluck(:user_id, :hour, :samples).group_by(&:first)

      @users.to_h do |user|
        [user.id, {
          hours_since_active: user.last_active_at && [(@now - user.last_active_at) / 3600.0, 0].max,
          matured_deliveries: received.fetch(user.id, 0),
          replied_within_24h: replied.fetch(user.id, 0),
          pending_conversations: pending_as_user.fetch(user.id, 0) + pending_as_opponent.fetch(user.id, 0),
          deliveries_last_24h: exposure.fetch(user.id, 0),
          availability: availability(user, hours.fetch(user.id, []))
        }]
      end
    end

    private

    def availability(user, rows)
      if rows.sum { |_, _, count| count } >= @config.fetch(:activity_min_samples)
        counts = rows.to_h { |_, hour, count| [hour, count] }
        # Adjacent hours smooth sparse observations; UTC records need no guessed geography.
        smoothed = (0...24).map { |hour| (-1..1).sum { |offset| counts.fetch((hour + offset) % 24, 0) } }
        return (smoothed[@now.utc.hour] + 1.0) / (smoothed.max + 1.0)
      end

      zone = ActiveSupport::TimeZone[user.time_zone] if user.time_zone.present?
      return 0.5 unless zone
      hour = @now.in_time_zone(zone).hour
      (@config.fetch(:awake_hour_start)...@config.fetch(:awake_hour_end)).cover?(hour) ? 0.75 : 0.25
    end
  end
end
