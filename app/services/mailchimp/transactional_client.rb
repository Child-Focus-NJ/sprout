# frozen_string_literal: true

require "httparty"

module Mailchimp
  # Direct Mailchimp Transactional (Mandrill) API client used by Rails for SMS.
  # Matches the v1.4 send-sms contract used by lambdas/mailchimp_realtime/sms_client.rb.
  class TransactionalClient
    include HTTParty
    base_uri "https://mandrillapp.com/api/1.4"

    CONSENT_TYPES = %w[onetime recurring recurring-no-confirm].freeze
    STATUSES = %w[sent queued scheduled rejected invalid].freeze

    class Error < StandardError; end
    class ConfigurationError < Error; end
    class ApiError < Error; end
    class UncertainDeliveryError < Error; end

    def initialize(api_key: ENV["MANDRILL_API_KEY"].presence || ENV["MAILCHIMP_API_KEY"])
      @api_key = api_key.to_s.strip
      raise ConfigurationError, "MANDRILL_API_KEY (or MAILCHIMP_API_KEY) is not set" if @api_key.blank?
    end

    # Returns { "status", "external_id", "to", "reject_reason" } like the Lambda SMS path.
    def send_sms(to:, message:, consent:, from: ENV["MANDRILL_SMS_FROM"].presence || ENV["MAILCHIMP_SMS_FROM"])
      from_number = from.to_s.strip
      raise ConfigurationError, "MANDRILL_SMS_FROM (or MAILCHIMP_SMS_FROM) is not set" if from_number.blank?
      unless CONSENT_TYPES.include?(consent)
        raise ApiError, "Invalid SMS consent type"
      end

      response = self.class.post(
        "/messages/send-sms",
        headers: { "Content-Type" => "application/json" },
        body: {
          key: @api_key,
          message: {
            sms: {
              to: [ to ],
              from: from_number,
              text: message,
              consent: consent
            }
          }
        }.to_json,
        timeout: 30
      )

      parse_sms_response!(response, expected_to: to)
    rescue JSON::ParserError, IOError, SystemCallError, Timeout::Error, SocketError, OpenSSL::SSL::SSLError => e
      raise UncertainDeliveryError, "SMS delivery could not be confirmed (#{e.class})"
    end

    # Returns { "status", "external_id", "to", "reject_reason" } like the Lambda email path.
    def send_email(to:, subject:, text_body:, from_email: ENV["MANDRILL_FROM_EMAIL"].presence || ENV["MAILCHIMP_EMAIL_FROM"])
      sender = from_email.to_s.strip
      raise ConfigurationError, "MANDRILL_FROM_EMAIL (or MAILCHIMP_EMAIL_FROM) is not set" if sender.blank?

      response = self.class.post(
        "/messages/send",
        headers: { "Content-Type" => "application/json" },
        body: {
          key: @api_key,
          message: {
            from_email: sender,
            to: [ { email: to, type: "to" } ],
            subject: subject,
            text: text_body,
            merge: false
          }
        }.to_json,
        timeout: 30
      )

      parse_email_response!(response, expected_to: to)
    rescue JSON::ParserError, IOError, SystemCallError, Timeout::Error, SocketError, OpenSSL::SSL::SSLError => e
      raise UncertainDeliveryError, "Email delivery could not be confirmed (#{e.class})"
    end

    private

    def parse_sms_response!(response, expected_to:)
      unless response.success?
        raise ApiError, "Mailchimp did not accept the SMS request (HTTP #{response.code})"
      end

      results = JSON.parse(response.body)
      result = results.first if results.is_a?(Array) && results.length == 1
      unless result.is_a?(Hash) && result["to"] == expected_to &&
          STATUSES.include?(result["status"]) && result["_id"].is_a?(String) && result["_id"].present?
        raise UncertainDeliveryError, "Mailchimp returned an unrecognized SMS result"
      end

      {
        "status" => result["status"],
        "external_id" => result["_id"],
        "to" => result["to"],
        "reject_reason" => result["reject_reason"]
      }
    end

    def parse_email_response!(response, expected_to:)
      unless response.success?
        raise ApiError, "Mailchimp did not accept the email request (HTTP #{response.code})"
      end

      results = JSON.parse(response.body)
      result = results.first if results.is_a?(Array) && results.length == 1
      unless result.is_a?(Hash) && result["email"].is_a?(String) && result["email"].casecmp?(expected_to) &&
          STATUSES.include?(result["status"]) && result["_id"].is_a?(String) && result["_id"].present?
        raise UncertainDeliveryError, "Mailchimp returned an unrecognized email result"
      end

      {
        "status" => result["status"],
        "external_id" => result["_id"],
        "to" => result["email"],
        "reject_reason" => result["reject_reason"]
      }
    end
  end
end
