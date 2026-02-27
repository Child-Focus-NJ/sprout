# frozen_string_literal: true

require "httparty"

module Aws
  class LambdaClient
    class LambdaError < StandardError; end

    def initialize
      @base_url = nil
    end

    def create_zoom_meeting(session_title:, start_time:, duration_minutes:)
      post("/zoom/meeting", {
        session_title: session_title,
        start_time: start_time.iso8601,
        duration_minutes: duration_minutes
      })
    end

    def sync_to_optima(volunteer_id:)
      post("/optima/sync", { volunteer_id: volunteer_id })
    end

    def send_email(to:, subject:, html_body:, from_email: nil)
      post("/mailchimp/send-email", {
        to: to,
        subject: subject,
        html_body: html_body,
        from_email: from_email
      })
    end

    def send_sms(to:, message:)
      post("/mailchimp/send-sms", { to: to, message: message })
    end

    def upsert_mailchimp_member(email:, first_name:, last_name:, tags: [])
      post("/mailchimp/member", {
        email: email,
        first_name: first_name,
        last_name: last_name,
        tags: tags
      })
    end

    def update_mailchimp_tags(email:, tags:)
      post("/mailchimp/tags", { email: email, tags: tags })
    end

    private

    def base_url
      @base_url ||= resolve_api_gateway_url
    end

    def resolve_api_gateway_url
      # In production, API_GATEWAY_URL is set directly as a full URL.
      # In local dev, the API ID is dynamic so we read it from a file
      # written by the LocalStack bootstrap script. The file may not
      # exist immediately if the bootstrap is still running, so we
      # retry briefly to handle the startup race condition.
      return ENV["API_GATEWAY_URL"] if ENV["API_GATEWAY_URL"]

      url_file = ENV["API_GATEWAY_URL_FILE"]
      raise "Set API_GATEWAY_URL or API_GATEWAY_URL_FILE" unless url_file

      3.times do
        return File.read(url_file).strip if File.exist?(url_file)
        sleep 2
      end

      raise "API Gateway URL file #{url_file} not found (LocalStack bootstrap may have failed)"
    end

    def post(path, body)
      response = HTTParty.post(
        "#{base_url}#{path}",
        headers: { "Content-Type" => "application/json" },
        body: body.to_json,
        timeout: 30
      )

      parsed = JSON.parse(response.body)

      unless response.success?
        raise LambdaError, "Lambda #{path} returned #{response.code}: #{parsed}"
      end

      parsed
    end
  end
end
