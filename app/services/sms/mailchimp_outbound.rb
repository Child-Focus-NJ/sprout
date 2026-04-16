# frozen_string_literal: true

module Sms
  # Outbound SMS for volunteers via Mailchimp (Mandrill transactional SMS / Mailchimp SMS),
  # invoked through the existing API Gateway + Lambda integration (`Aws::LambdaClient#send_sms`).
  #
  # See meeting notes: SMS is integrated with Mailchimp; credentials supplied when ready for testing.
  class MailchimpOutbound
    MAX_MESSAGE_LENGTH = 320

    class Error < StandardError; end
    class MissingPhoneError < Error; end
    class BlankMessageError < Error; end
    class MessageTooLongError < Error; end

    class << self
      def deliver!(volunteer:, body:, sent_by_user:)
        message = body.to_s.strip
        raise BlankMessageError, "Message cannot be blank" if message.blank?
        if message.length > MAX_MESSAGE_LENGTH
          raise MessageTooLongError, "Message is too long (max #{MAX_MESSAGE_LENGTH} characters)"
        end
        raise MissingPhoneError, "Add a phone number before sending SMS" if volunteer.phone.blank?

        if deliver_via_mailchimp_api?
          deliver_with_mailchimp_lambda!(volunteer: volunteer, message: message, sent_by_user: sent_by_user)
        else
          deliver_locally_recorded!(volunteer: volunteer, message: message, sent_by_user: sent_by_user)
        end
      end

      private

      def deliver_locally_recorded!(volunteer:, message:, sent_by_user:)
        # Development / test / when Mailchimp is not enabled: record the send only (no HTTP).
        volunteer.communications.create!(
          communication_type: :sms,
          body: message,
          sent_at: Time.current,
          sent_by_user: sent_by_user
        )
      end

      def deliver_with_mailchimp_lambda!(volunteer:, message:, sent_by_user:)
        communication = volunteer.communications.create!(
          communication_type: :sms,
          body: message,
          sent_by_user: sent_by_user,
          status: :pending,
          sent_at: nil
        )

        Aws::LambdaClient.new.send_sms(to: format_e164_us(volunteer.phone), message: message)
        communication.update!(sent_at: Time.current, status: :delivered)
        communication
      rescue Aws::LambdaClient::LambdaError, StandardError => e
        Rails.logger.error("[Sms::MailchimpOutbound] send failed: #{e.class}: #{e.message}")
        communication.update!(status: :failed)
        raise Error, "SMS could not be sent. Please try again or check Mailchimp configuration."
      end

      def deliver_via_mailchimp_api?
        ActiveModel::Type::Boolean.new.cast(ENV.fetch("SPROUT_SMS_MAILCHIMP_ENABLED", "false")) &&
          api_gateway_configured?
      end

      def api_gateway_configured?
        return true if ENV["API_GATEWAY_URL"].present?

        file = ENV["API_GATEWAY_URL_FILE"].to_s
        file.present? && File.exist?(file)
      end

      # Lambda expects a dialable number; normalize US numbers to E.164.
      def format_e164_us(phone)
        digits = phone.to_s.gsub(/\D/, "")
        return phone.to_s.strip if digits.blank?

        core = digits.length > 10 ? digits[-10, 10] : digits
        return phone.to_s.strip unless core.length == 10

        "+1#{core}"
      end
    end
  end
end
