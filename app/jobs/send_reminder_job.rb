class SendReminderJob < ApplicationJob
  queue_as :default

  def perform(scheduled_reminder)
    return unless scheduled_reminder.pending?

    communication = Email::TemplateDelivery.record!(
      volunteer: scheduled_reminder.volunteer, template: scheduled_reminder.communication_template
    )
    Email::TemplateDelivery.deliver!(communication) do
      scheduled_reminder.update!(status: :sent, sent_at: Time.current)
    end
  rescue StandardError => e
    scheduled_reminder.update!(status: :skipped, skip_reason: e.message.to_s.truncate(255))
    raise
  end
end
