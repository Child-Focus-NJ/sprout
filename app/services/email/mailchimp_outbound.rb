# frozen_string_literal: true

module Email
  class MailchimpOutbound
    MAX_SUBJECT_LENGTH = 998
    class Error < StandardError; end
    class ValidationError < Error; end
    class ConfigurationError < Error; end
    class DuplicateApplicationError < Error; end

    def self.deliver!(volunteer:, subject:, body:, sent_by_user: nil, purpose: nil)
      communication = volunteer.with_lock do
        if purpose == "application"
          if volunteer.application_sent_at.present? || volunteer.applied?
            raise DuplicateApplicationError, "Application was already sent or submitted"
          end
          if volunteer.communications.email.where(purpose: "application", status: [ :pending, :queued, :sent, :delivered ]).exists?
            raise DuplicateApplicationError, "An application email is already pending, queued, or sent. Check Mailchimp activity before resending."
          end
        end

        recipient = volunteer.email.to_s.strip
        unless recipient.match?(URI::MailTo::EMAIL_REGEXP)
          raise ValidationError, "Enter a valid email address before sending email"
        end
        subject = subject.to_s.strip
        body = body.to_s.strip
        raise ValidationError, "Subject cannot be blank" if subject.blank?
        raise ValidationError, "Subject is too long (maximum #{MAX_SUBJECT_LENGTH} characters)" if subject.length > MAX_SUBJECT_LENGTH
        raise ValidationError, "Subject must be a single line" if subject.match?(/[\r\n]/)
        raise ValidationError, "Message cannot be blank" if body.blank?
        unless ActiveModel::Type::Boolean.new.cast(ENV.fetch("SPROUT_EMAIL_MAILCHIMP_ENABLED", "false"))
          raise ConfigurationError, "Email sending is not enabled. Contact your administrator."
        end

        volunteer.communications.create!(
          communication_type: :email, subject: subject, body: body, email_to: recipient,
          sent_by_user: sent_by_user, purpose: purpose, status: :pending
        )
      end
      send_message!(communication)
    end

    def self.send_message!(communication)
      result = Mailchimp::TransactionalClient.new.send_email(
        to: communication.email_to, subject: communication.subject, text_body: communication.body
      )
      unless result.is_a?(Hash) && result["to"].is_a?(String) && result["to"].casecmp?(communication.email_to) &&
          result["external_id"].is_a?(String) && result["external_id"].present? &&
          %w[sent queued scheduled rejected invalid].include?(result["status"])
        raise Mailchimp::TransactionalClient::UncertainDeliveryError, "Unrecognized email result"
      end

      status = case result["status"]
      when "sent" then :sent
      when "queued", "scheduled" then :queued
      else :failed
      end
      communication.transaction do
        communication.update!(
          status: status, external_id: result["external_id"], sent_at: status == :sent ? Time.current : nil,
          error_message: status == :failed ? "Mailchimp rejected the email (#{result['reject_reason'].presence || result['status']})" : nil
        )
        if communication.sent? && communication.purpose == "application"
          communication.volunteer.with_lock do
            communication.volunteer.record_application_sent!(user: communication.sent_by_user, sent_at: communication.sent_at)
          end
        end
      end
      raise Error, "Mailchimp rejected the email. Check the communication history for details." if communication.failed?

      communication
    rescue Mailchimp::TransactionalClient::UncertainDeliveryError
      message = "Email delivery could not be confirmed. Check Mailchimp activity before resending."
      communication.update!(error_message: message)
      raise Error, message
    rescue Mailchimp::TransactionalClient::Error
      message = "Email could not be sent. Check Mailchimp configuration."
      communication.update!(status: :failed, error_message: message)
      raise Error, message
    end
    private_class_method :send_message!
  end
end
