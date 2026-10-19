class Admin::MarketingController < Admin::BaseController
  def show
    through = parse_date(params[:through]) || Date.current
    through = [ through, Date.current ].min
    from = parse_date(params[:from]) || through - 13
    from = [ [ from, through ].min, through - 89 ].max
    @report = MarketingReport.new(from: from, through: through, source: params[:source].to_s.strip.first(120), campaign: params[:campaign].to_s.strip.first(120))
    @summary = @report.summary
    @retention = @report.retention_totals
  end

  private

  def parse_date(value)
    Date.iso8601(value.to_s)
  rescue Date::Error
    nil
  end
end
