module AiAllowance
  private

  def training_usage
    @training_usage ||= AiUsage.start_day!(user: current_user, visitor_id: training_visitor_id, date: Date.current)
  end

  def training_visitor_id
    visitor_id = cookies.encrypted[:ai_visitor_id]
    return visitor_id if visitor_id.present?

    visitor_id = SecureRandom.uuid
    cookies.encrypted.permanent[:ai_visitor_id] = {
      value: visitor_id, httponly: true, same_site: request.ssl? ? :none : :lax, secure: request.ssl?
    }
    visitor_id
  end

  def fetch_daily_ai!(mode:, text:, &block)
    AiUsage.fetch!(usage: training_usage, mode: mode, input: "#{I18n.locale}:#{text}", ip: current_user ? nil : request.remote_ip, &block)
  end
end
