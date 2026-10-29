# frozen_string_literal: true

require "httparty"

module Mailchimp
  # Direct Mailchimp Transactional (Mandrill) API client used by Rails for SMS and email.
  # This is the only send path. Consent values live here so callers do not keep a second copy.
  class TransactionalClient
    include HTTParty
    base_uri "https://mandrillapp.com/api/1.4"

    CONSENT_TYPES = %w[onetime recurring recurring-no-confirm].freeze
    STATUSES = %w[sent queued scheduled rejected invalid].freeze
    EMAIL_STATES = %w[sent bounced rejected queued scheduled canceled].freeze

    class Error < StandardError; end
    class ConfigurationError < Error; end
    class ApiError < Error; end
    class UncertainDeliveryError < Error; end

    # Encrypted credentials (config/master.key) are the source of truth.
    # Environment variables remain a fallback so the test suite can supply values
    # without a Mandrill entry in the credentials file. Tests prefer the environment
    # so a developer key in the vault cannot change assertions.
    def self.credential(key, *env_names)
      candidates = []
      candidates << environment_value(env_names) if Rails.env.test?
      candidates << credentials_value(key)
      candidates << environment_value(env_names) unless Rails.env.test?
      candidates.find(&:present?)
    end

    def self.credentials_value(key)
      Rails.application.credentials.dig(:mandrill, key)
    rescue ActiveSupport::EncryptedFile::MissingKeyError, ActiveSupport::MessageEncryptor::InvalidMessage
      nil
    end
    private_class_method :credentials_value

    def self.environment_value(env_names)
      env_names.each do |name|
        value = ENV[name].presence
        return value if value
      end
      nil
    end
    private_class_method :environment_value

    def initialize(api_key: self.class.credential(:api_key, "MANDRILL_API_KEY", "MAILCHIMP_API_KEY"))
      @api_key = api_key.to_s.strip
      raise ConfigurationError, "Mandrill API key is not set in the encrypted credentials" if @api_key.blank?
    end

    # Returns { "status", "external_id", "to", "reject_reason" }.
    def send_sms(to:, message:, consent:, from: self.class.credential(:sms_from, "MANDRILL_SMS_FROM", "MAILCHIMP_SMS_FROM"))
      from_number = from.to_s.strip
      raise ConfigurationError, "Mandrill SMS sender is not set in the encrypted credentials" if from_number.blank?
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
    def send_email(to:, subject:, text_body:, from_email: self.class.credential(:from_email, "MANDRILL_FROM_EMAIL", "MAILCHIMP_EMAIL_FROM"))
      sender = from_email.to_s.strip
      raise ConfigurationError, "Mandrill From address is not set in the encrypted credentials" if sender.blank?

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

    # Read the original attempt; never resend a queued message to check its status.
    def email_info(id:, to:)
      response = self.class.post(
        "/messages/info",
        headers: { "Content-Type" => "application/json" },
        body: { key: @api_key, id: id }.to_json,
        timeout: 30
      )
      raise ApiError, "Email status is unavailable (HTTP #{response.code})" unless response.success?

      result = JSON.parse(response.body)
      unless result.is_a?(Hash) && result["_id"] == id &&
          result["email"].is_a?(String) && result["email"].casecmp?(to) &&
          EMAIL_STATES.include?(result["state"]) && result["ts"].is_a?(Integer) && result["ts"].positive?
        raise UncertainDeliveryError, "Mailchimp returned an unrecognized email status"
      end

      { "status" => result["state"], "sent_at" => Time.at(result["ts"]).utc }
    rescue JSON::ParserError, IOError, SystemCallError, Timeout::Error, SocketError, OpenSSL::SSL::SSLError
      raise UncertainDeliveryError, "Email status could not be confirmed"
    end

    private

    def parse_sms_response!(response, expected_to:)
      unless response.success?
        if response.code.to_i >= 500
          raise UncertainDeliveryError, "Mailchimp SMS delivery could not be confirmed (HTTP #{response.code})"
        end
        raise ApiError, "Mailchimp did not accept the SMS request (HTTP #{response.code})"
      end

      results = JSON.parse(response.body)
      result = results.first if results.is_a?(Array) && results.length == 1
      # Mailchimp may reformat the number it accepted. Compare digits so spacing or
      # punctuation on a successful send is not treated as an unrecognized result.
      unless result.is_a?(Hash) && same_phone_number?(result["to"], expected_to) &&
          STATUSES.include?(result["status"]) && result["_id"].is_a?(String) && result["_id"].present?
        raise UncertainDeliveryError, "Mailchimp returned an unrecognized SMS result"
      end

      {
        "status" => result["status"],
        "external_id" => result["_id"],
        "to" => expected_to,
        "reject_reason" => result["reject_reason"]
      }
    end

    def same_phone_number?(returned, expected)
      returned_digits = returned.to_s.gsub(/\D/, "")
      expected_digits = expected.to_s.gsub(/\D/, "")
      returned_digits.present? && returned_digits == expected_digits
    end

    def parse_email_response!(response, expected_to:)
      unless response.success?
        if response.code >= 500
          raise UncertainDeliveryError, "Email delivery could not be confirmed"
        end
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
