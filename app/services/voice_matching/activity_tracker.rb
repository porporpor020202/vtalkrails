module VoiceMatching
  class ActivityTracker
    def self.call(user, time_zone: nil, now: Time.current)
      return if user.last_active_at && user.last_active_at > now - 5.minutes
      attributes = { last_active_at: now }
      if time_zone.present? && time_zone.bytesize <= 100 && ActiveSupport::TimeZone[time_zone]
        attributes[:time_zone] = time_zone
      end
      User.transaction do
        changed = User.where(id: user.id).where("last_active_at IS NULL OR last_active_at <= ?", now - 5.minutes)
          .update_all(attributes)
        return if changed.zero?
        # Bounded to 24 rows per user. Discard a bucket's old samples after the history window.
        history = Rails.application.config_for(:voice_matching).fetch(:history_days).days
        UserActivityHour.upsert({ user_id: user.id, hour: now.utc.hour, samples: 1, created_at: now, updated_at: now },
          unique_by: [:user_id, :hour],
          on_duplicate: Arel.sql("samples = CASE WHEN user_activity_hours.updated_at < #{UserActivityHour.connection.quote(now - history)} THEN 1 ELSE user_activity_hours.samples + 1 END, updated_at = EXCLUDED.updated_at"))
      end
    end
  end
end
