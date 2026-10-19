class MarketingReport
  RECORDED = %w[recording_completed practice_completed].freeze
  STAGES = {
    question_translation: %w[question_translation_used],
    answer_translation: %w[answer_translation_used],
    recording_started: %w[recording_started recording_completed practice_completed],
    recording_completed: RECORDED,
    practice_completed: %w[practice_completed],
    signup_visitors: %w[signup]
  }.freeze
  DAY = "DATE(marketing_events.occurred_at AT TIME ZONE 'Asia/Seoul')".freeze
  attr_reader :from, :through, :source, :campaign

  def initialize(from:, through:, source: "", campaign: "")
    @from, @through, @source, @campaign = from, through, source, campaign
  end

  def collection_started_at
    MarketingVisit.external.minimum(:started_at)
  end

  def summary
    @summary ||= begin
      counts = STAGES.transform_values { |names| events.where(name: names).distinct.count("marketing_visits.visitor_key") }
      guests = events.where(name: RECORDED, authenticated: false)
      converted = guests.where(<<~SQL.squish, through.end_of_day)
        EXISTS (
          SELECT 1 FROM marketing_events signups
          JOIN marketing_visits signup_visits ON signup_visits.id = signups.marketing_visit_id
          WHERE signups.name = 'signup' AND signup_visits.internal = FALSE
            AND signup_visits.visitor_key = marketing_visits.visitor_key
            AND signups.occurred_at >= marketing_events.occurred_at AND signups.occurred_at <= ?
        )
      SQL
      counts.merge(
        visitors: visits.distinct.count(:visitor_key),
        new_accounts: signups.distinct.count(:user_id),
        unattributed_signups: signups.where(marketing_visit_id: nil).distinct.count(:user_id),
        guest_recorders: guests.distinct.count("marketing_visits.visitor_key"),
        recorded_then_signup: converted.distinct.count("marketing_visits.visitor_key"),
        saved_after_login: events.where(name: "guest_recording_claimed").distinct.count("marketing_visits.visitor_key")
      )
    end
  end

  def sources
    # Each row counts devices, not page views. A device can appear in multiple campaigns.
    joined = visits.joins("LEFT JOIN (#{MarketingEvent.where(occurred_at: from.beginning_of_day..through.end_of_day).to_sql}) marketing_events ON marketing_events.marketing_visit_id = marketing_visits.id")
    columns = %w[source medium campaign content].map { |key| "marketing_visits.#{key}" }
    joined.group(*columns).order(Arel.sql("COUNT(DISTINCT marketing_visits.visitor_key) DESC")).limit(100).pluck(
      *columns, Arel.sql("COUNT(DISTINCT marketing_visits.visitor_key)"),
      *%w[answer_translation_used recording_completed practice_completed signup].map { |name|
        names = name == "recording_completed" ? "'recording_completed', 'practice_completed'" : "'#{name}'"
        Arel.sql("COUNT(DISTINCT CASE WHEN marketing_events.name IN (#{names}) THEN marketing_visits.visitor_key END)")
      }
    ).map { |values| %i[source medium campaign content visitors translated recorded saved signed_up].zip(values).to_h }
  end

  def retention
    @retention ||= begin
      daily = signups.group(Arel.sql(DAY)).distinct.count(:user_id)
      returned = signups.where(<<~SQL.squish).group(Arel.sql(DAY)).distinct.count(:user_id)
        EXISTS (
          SELECT 1 FROM marketing_events activity
          JOIN marketing_visits visits ON visits.id = activity.marketing_visit_id
          WHERE activity.user_id = marketing_events.user_id AND activity.name = 'app_open' AND visits.internal = FALSE
            AND DATE(activity.occurred_at AT TIME ZONE 'Asia/Seoul') = #{DAY} + 1
        )
        OR EXISTS (
          SELECT 1 FROM daily_practices practice WHERE practice.user_id = marketing_events.user_id
            AND practice.practiced_on = #{DAY} + 1
        )
      SQL
      practiced = signups.where(<<~SQL.squish).group(Arel.sql(DAY)).distinct.count(:user_id)
        EXISTS (
          SELECT 1 FROM daily_practices practice WHERE practice.user_id = marketing_events.user_id
            AND practice.practiced_on = #{DAY} + 1
        )
      SQL
      daily.sort.reverse.map do |date, count|
        { date: date, signups: count, returned: returned.fetch(date, 0), practiced: practiced.fetch(date, 0), mature: date < Date.yesterday }
      end
    end
  end

  def retention_totals
    mature = retention.select { |row| row[:mature] }
    %i[signups returned practiced].index_with { |key| mature.sum { |row| row[key] } }.merge(pending: retention.reject { |row| row[:mature] }.sum { |row| row[:signups] })
  end

  def filter_options
    MarketingVisit.external.distinct.order(:source).pluck(:source)
  end

  private

  def filtered_visits
    scope = MarketingVisit.external
    scope = scope.where(source: source) if source.present?
    scope = scope.where(campaign: campaign) if campaign.present?
    scope
  end

  def visits
    filtered_visits.where(started_at: from.beginning_of_day..through.end_of_day)
  end

  def events
    MarketingEvent.joins(:marketing_visit).where(marketing_visit_id: visits.select(:id), occurred_at: from.beginning_of_day..through.end_of_day)
  end

  def signups
    scope = MarketingEvent.joins(:user).where.not(users: { email_address: User::ADMIN_EMAIL }).where(name: "signup", occurred_at: from.beginning_of_day..through.end_of_day)
    scope = scope.where(marketing_visit_id: filtered_visits.select(:id)) if source.present? || campaign.present?
    scope.left_joins(:marketing_visit).where(marketing_visits: { internal: [ false, nil ] })
  end
end
