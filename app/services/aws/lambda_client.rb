# frozen_string_literal: true

require "httparty"

module Aws
  class LambdaClient
    class LambdaError < StandardError; end
    class UncertainDeliveryError < LambdaError; end

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

    def sync_to_volunteer_management_system(volunteer_id:)
      post("/volunteer-management-system/sync", { volunteer_id: volunteer_id })
    end

    def send_email(to:, subject:, text_body:)
      post("/mailchimp/send-email", {
        to: to,
        subject: subject,
        text_body: text_body
      })
    rescue JSON::ParserError, IOError, SystemCallError, Timeout::Error, SocketError, OpenSSL::SSL::SSLError
      raise UncertainDeliveryError, "Email delivery could not be confirmed"
    end

    def send_sms(to:, message:, consent:)
      post("/mailchimp/send-sms", { to: to, message: message, consent: consent })
    rescue JSON::ParserError, IOError, SystemCallError, Timeout::Error, SocketError, OpenSSL::SSL::SSLError
      raise UncertainDeliveryError, "SMS delivery could not be confirmed"
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
      return ENV["API_GATEWAY_URL"].strip if ENV["API_GATEWAY_URL"].present?

      url_file = ENV["API_GATEWAY_URL_FILE"]
      raise LambdaError, "Set API_GATEWAY_URL or API_GATEWAY_URL_FILE" if url_file.blank?

      # Wait for LocalStack bootstrap.
      3.times do
        if File.file?(url_file)
          url = File.read(url_file).strip
          return url if url.present?
        end
        sleep 2
      end

      raise LambdaError, "API Gateway URL file is unavailable (LocalStack bootstrap may have failed)"
    end

    def post(path, body)
      response = HTTParty.post(
        "#{base_url}#{path}",
        headers: { "Content-Type" => "application/json" },
        body: body.to_json,
        timeout: 30
      )

      unless response.success?
        if %w[/mailchimp/send-sms /mailchimp/send-email].include?(path) && [ 500, 502, 504 ].include?(response.code)
          raise UncertainDeliveryError, "Delivery could not be confirmed"
        end
        raise LambdaError, "Lambda #{path} returned #{response.code}"
      end

      JSON.parse(response.body)
    end
  end
end
