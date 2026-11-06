# frozen_string_literal: true

module Email
  class VolunteerNotifications
    def self.inquiry!(volunteer:)
      message = InquiryMailer.confirmation(volunteer.email).message
      MailchimpOutbound.deliver!(
        volunteer: volunteer, subject: message.subject, body: message.body.decoded, purpose: "inquiry"
      )
    end

    def self.application!(volunteer:, sent_by_user:)
      if volunteer.application_sent_at.present? || volunteer.applied?
        raise MailchimpOutbound::DuplicateApplicationError, "Application was already sent or submitted"
      end
      url = SystemSetting.get("application_url").to_s.strip
      unless url.present? && SystemSetting.valid_application_url?(url)
        raise MailchimpOutbound::ConfigurationError, "Set the application link in Admin settings before sending an application email."
      end

      message = AttendanceMailer.application(volunteer.email, application_url: url).message
      MailchimpOutbound.deliver!(
        volunteer: volunteer, subject: message.subject, body: message.body.decoded,
        sent_by_user: sent_by_user, purpose: "application"
      )
    end
  end
end
