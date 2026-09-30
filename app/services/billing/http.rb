require "net/http"
require "json"

module Billing
  class Http
    def self.call(method, url, token:, body: nil)
      uri = URI(url)
      raise Error, "Invalid billing endpoint" unless uri.scheme == "https"
      request = { get: Net::HTTP::Get, post: Net::HTTP::Post }.fetch(method).new(uri)
      request["Authorization"] = "Bearer #{token}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(body) if body
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15, write_timeout: 10) do |http|
        http.max_retries = 0
        http.request(request)
      end
      raise Error, "Payment provider could not verify the request." unless response.is_a?(Net::HTTPSuccess)
      response.body.blank? ? {} : JSON.parse(response.body)
    rescue JSON::ParserError, IOError, SystemCallError, Timeout::Error, SocketError, OpenSSL::SSL::SSLError
      raise Error, "Payment provider is temporarily unavailable."
    end

    def self.segment(value)
      ERB::Util.url_encode(value.to_s)
    end
  end
end
