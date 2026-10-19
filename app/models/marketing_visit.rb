require "uri"

class MarketingVisit < ApplicationRecord
  belongs_to :user, optional: true
  has_many :marketing_events, dependent: :delete_all
  scope :external, -> { where(internal: false) }
  validates :visitor_key, :started_at, :last_seen_at, :source, :medium, :landing_path, :platform, presence: true

  def self.attribution(request, platform:)
    host = referrer_host(request.referer)
    host = nil if host == request.host || %w[sayonething.net www.sayonething.net accounts.google.com appleid.apple.com].include?(host)
    tags = %w[source medium campaign content].index_with { |key| request.query_parameters["utm_#{key}"].to_s.gsub(/[[:cntrl:]]/, "").strip.first(120).presence }
    source = tags["source"] || host&.delete_prefix("www.") || (platform == "web" ? "direct" : "app")
    {
      source: source, medium: tags["medium"] || (host ? "referral" : "unknown"),
      campaign: tags["campaign"], content: tags["content"], referrer_host: host&.first(253),
      landing_path: request.path.first(200), platform: platform
    }
  end

  def self.referrer_host(value)
    URI.parse(value.to_s).host&.downcase
  rescue URI::InvalidURIError
    nil
  end
  private_class_method :referrer_host
end
