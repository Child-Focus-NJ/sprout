# frozen_string_literal: true

module Email
  class QueuedDelivery
    def self.refresh!(communication)
      return unless communication.email? && communication.queued? && communication.external_id.present?

      result = Mailchimp::TransactionalClient.new.email_info(id: communication.external_id, to: communication.email_to)
      communication.volunteer.with_lock do
        communication.with_lock do
          return unless communication.queued?

          case result.fetch("status")
          when "sent"
            communication.update!(status: :sent, sent_at: result.fetch("sent_at"), error_message: nil)
            if communication.purpose == "application"
              communication.volunteer.record_application_sent!(user: communication.sent_by_user, sent_at: communication.sent_at)
            end
          when "bounced"
            communication.update!(status: :bounced, error_message: "Mailchimp reported that the email bounced.")
          when "rejected", "canceled"
            communication.update!(status: :failed, error_message: "Mailchimp reported the email as #{result.fetch('status')}.")
          end
        end
      end
    end
  end
end
