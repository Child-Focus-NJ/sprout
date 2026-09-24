# frozen_string_literal: true

require "httparty"

module Mailchimp
  # Direct Mailchimp Marketing API client (no Lambda / API Gateway).
  class MarketingClient
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class ApiError < Error; end

    def initialize(api_key: ENV["MAILCHIMP_API_KEY"])
      @api_key = api_key.to_s.strip
      raise ConfigurationError, "MAILCHIMP_API_KEY is not set" if @api_key.blank?

      @datacenter = @api_key.split("-").last
      raise ConfigurationError, "MAILCHIMP_API_KEY is missing a datacenter suffix (e.g. -us2)" if @datacenter.blank? || !@datacenter.match?(/\A[a-z]+\d+\z/)

      @base_uri = "https://#{@datacenter}.api.mailchimp.com/3.0"
    end

    # Returns a Hash with "campaigns" and "total_items" (Mailchimp shape).
    def list_campaigns(count: 50, offset: 0, status: nil, since_create_time: nil)
      query = {
        count: count,
        offset: offset,
        sort_field: "create_time",
        sort_dir: "DESC",
        fields: "campaigns.id,campaigns.web_id,campaigns.status,campaigns.type,campaigns.create_time,campaigns.send_time,campaigns.settings.title,campaigns.settings.subject_line,campaigns.archive_url,total_items"
      }
      query[:status] = status if status.present?
      query[:since_create_time] = since_create_time if since_create_time.present?

      get("/campaigns", query)
    end

    private

    def get(path, query = {})
      response = HTTParty.get(
        "#{@base_uri}#{path}",
        query: query,
        basic_auth: { username: "anystring", password: @api_key },
        headers: { "Content-Type" => "application/json" },
        timeout: 30
      )

      parsed = parse_json(response.body)
      unless response.success?
        detail = parsed.is_a?(Hash) ? (parsed["detail"] || parsed["title"] || parsed.inspect) : response.body
        raise ApiError, "Mailchimp Marketing API #{path} returned #{response.code}: #{detail}"
      end

      parsed
    end

    def parse_json(body)
      JSON.parse(body.presence || "{}")
    rescue JSON::ParserError
      {}
    end
  end
end
