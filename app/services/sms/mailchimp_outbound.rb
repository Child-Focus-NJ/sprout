# frozen_string_literal: true

module Sms
  class MailchimpOutbound
    MAX_MESSAGE_LENGTH = 320
    CONSENT_TYPES = %w[onetime recurring recurring-no-confirm].freeze

    class Error < StandardError; end
    class MissingPhoneError < Error; end
    class InvalidPhoneError < Error; end
    class BlankMessageError < Error; end
    class MessageTooLongError < Error; end
    class MissingConsentError < Error; end
    class ConfigurationError < Error; end

    def self.deliver!(volunteer:, body:, sent_by_user:, consent: nil)
      message = body.to_s.strip
      raise BlankMessageError, "Message cannot be blank" if message.blank?
      if message.length > MAX_MESSAGE_LENGTH
        raise MessageTooLongError, "Message is too long (max #{MAX_MESSAGE_LENGTH} characters)"
      end
      raise MissingPhoneError, "Add a phone number before sending SMS" if volunteer.phone.blank?

      phone = normalize_phone(volunteer.phone)
      unless CONSENT_TYPES.include?(consent)
        raise MissingConsentError, "Select the SMS consent the volunteer has provided"
      end
      unless ActiveModel::Type::Boolean.new.cast(ENV.fetch("SPROUT_SMS_MAILCHIMP_ENABLED", "false"))
        raise ConfigurationError, "SMS sending is not enabled. Contact your administrator."
      end

      communication = volunteer.communications.create!(
        communication_type: :sms, body: message, sent_by_user: sent_by_user,
        status: :pending, sms_to: phone, sms_consent: consent
      )
      send_message!(communication)
    end

    def self.normalize_phone(phone)
      value = phone.to_s.strip
      unless value.match?(/\A\+?[\d\s().-]+\z/)
        raise InvalidPhoneError, "Enter a valid phone number before sending SMS"
      end

      digits = value.gsub(/\D/, "")
      normalized = if value.start_with?("+")
        "+#{digits}"
      elsif digits.length == 10
        "+1#{digits}"
      elsif digits.length == 11 && digits.start_with?("1")
        "+#{digits}"
      end
      unless normalized&.match?(/\A\+[1-9]\d{7,14}\z/)
        raise InvalidPhoneError, "Enter a valid phone number, including the country code for international numbers"
      end
      normalized
    end

    def self.send_message!(communication)
      result = Mailchimp::TransactionalClient.new.send_sms(
        to: communication.sms_to,
        message: communication.body,
        consent: communication.sms_consent
      )
      unless result.is_a?(Hash) && result["to"] == communication.sms_to && result["external_id"].is_a?(String) &&
          result["external_id"].present? && %w[sent queued scheduled rejected invalid].include?(result["status"])
        raise Mailchimp::TransactionalClient::UncertainDeliveryError, "Unrecognized SMS result"
      end

      status = case result["status"]
      when "sent" then :sent
      when "queued", "scheduled" then :queued
      else :failed
      end
      communication.update!(
        status: status, external_id: result["external_id"],
        sent_at: status == :sent ? Time.current : nil,
        error_message: status == :failed ? "Mailchimp rejected the SMS (#{result['reject_reason'].presence || result['status']})" : nil
      )
      raise Error, "Mailchimp rejected the SMS. Check the communication history for details." if communication.failed?

      communication
    rescue Mailchimp::TransactionalClient::UncertainDeliveryError
      message = "SMS delivery could not be confirmed. Check Mailchimp activity before resending."
      communication.update!(error_message: message)
      raise Error, message
    rescue Mailchimp::TransactionalClient::Error
      message = "SMS could not be sent. Check Mailchimp configuration."
      communication.update!(status: :failed, error_message: message)
      raise Error, message
    end
    private_class_method :send_message!
  end
end
