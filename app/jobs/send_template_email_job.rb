# Sends one email queued by the Volunteers list's bulk Send Email, the same way as a follow-up
# reminder. It claims the email, so only one worker can send it. If the email goes out but
# marking it sent fails, it stays "sending" and isn't resent.
class SendTemplateEmailJob < ApplicationJob
  queue_as :default

  def perform(communication_id)
    claimed = Communication.where(id: communication_id, status: :pending)
                           .update_all(status: Communication.statuses[:sending], updated_at: Time.current)
    return if claimed.zero?

    communication = Communication.find(communication_id)
    unless Email.sending_enabled?
      # Turned off after this was queued, so record why it didn't go out
      communication.update!(status: :failed, error_message: Email::DISABLED_MESSAGE)
      return
    end

    Email::TemplateDelivery.deliver!(communication)
  end
end
