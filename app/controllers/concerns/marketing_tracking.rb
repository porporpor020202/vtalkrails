module MarketingTracking
  extend ActiveSupport::Concern

  included do
    before_action :track_marketing_entry
  end

  private

  def track_marketing_entry
    return unless request.get? && request.format.html?
    return unless %w[daily_practices bonus_practices native_languages sessions settings].include?(controller_path)

    track_marketing("app_open")
  end

  def marketing_visit
    return @marketing_visit if defined?(@marketing_visit)
    return if request.head? || request.user_agent.to_s.match?(/bot|crawler|spider|facebookexternalhit|kakaotalk-scrap|WhatsApp\/[0-9]/i)
    return if request.headers["Sec-Purpose"].to_s.include?("prefetch") || request.headers["Purpose"] == "prefetch"

    visitor_key = cookies.encrypted[:marketing_visitor_id]
    unless visitor_key.is_a?(String) && visitor_key.match?(/\A[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\z/)
      visitor_key = SecureRandom.uuid
      marketing_cookie(:marketing_visitor_id, visitor_key)
    end
    visit = MarketingVisit.find_by(id: cookies.encrypted[:marketing_visit_id], visitor_key: visitor_key)
    platform = ios_app? ? "ios" : android_app? ? "android" : "web"
    attribution = MarketingVisit.attribution(request, platform: platform)
    attributed_entry = request.get? && (request.query_parameters["utm_source"].present? || attribution[:referrer_host].present?)
    different_campaign = attributed_entry && visit && %w[source medium campaign content].any? { |key| visit.public_send(key).to_s != attribution[key.to_sym].to_s }
    different_account = visit&.user_id.present? && visit.user_id != current_user&.id
    if !visit || visit.last_seen_at < 30.minutes.ago || different_campaign || different_account
      visit = MarketingVisit.create!(**attribution, visitor_key: visitor_key, user: current_user, internal: current_user&.marketing_internal? || false, started_at: Time.current, last_seen_at: Time.current)
      marketing_cookie(:marketing_visit_id, visit.id)
    elsif visit.last_seen_at < 1.minute.ago
      visit.update!(last_seen_at: Time.current)
    end
    @marketing_visit = visit
  rescue ActiveRecord::ActiveRecordError => error
    Rails.logger.warn("Marketing visit unavailable: #{error.class}")
    @marketing_visit = nil
  end

  def marketing_cookie(name, value)
    cookies.encrypted[name] = { value: value, expires: 180.days.from_now, httponly: true, same_site: request.ssl? ? :none : :lax, secure: request.ssl? }
  end

  def track_marketing(name, context: "daily", key: nil, at: Time.current, authenticated: current_user.present?)
    visit = marketing_visit
    return unless visit

    MarketingEvent.capture(name: name, visit: visit, user: current_user, context: context, occurred_at: at, authenticated: authenticated, deduplication_key: key || "visit:#{visit.id}:#{name}:#{Date.current}:#{context}")
  end

  def link_marketing_account(user, session_record:)
    remove_instance_variable(:@marketing_visit) if defined?(@marketing_visit)
    visit = marketing_visit
    return unless visit

    visit.update!(user: user, internal: user.marketing_internal?)
    if user.marketing_internal?
      MarketingVisit.where(visitor_key: visit.visitor_key, user_id: [ nil, user.id ]).update_all(internal: true)
      return
    end
    # Keep authenticated=false on pre-login events so the guest conversion stays measurable.
    visit.marketing_events.where(user_id: nil).update_all(user_id: user.id)
    MarketingEvent.where(name: "signup", user_id: user.id, marketing_visit_id: nil).update_all(marketing_visit_id: visit.id)
    track_marketing("login", key: "login:#{session_record.id}")
    track_marketing("app_open")
  rescue ActiveRecord::ActiveRecordError => error
    Rails.logger.warn("Marketing account link unavailable: #{error.class}")
  end
end
