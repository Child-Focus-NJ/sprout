class SendReminderJob < ApplicationJob
  queue_as :default

  def perform(scheduled_reminder)
    return unless scheduled_reminder.pending?

    volunteer = scheduled_reminder.volunteer
    template  = scheduled_reminder.communication_template

    communication = Communication.create!(
      volunteer: volunteer,
      communication_template: template,
      communication_type: template.template_type,
      subject: template.render_subject(volunteer),
      body: template.render_body(volunteer),
      status: :pending
    )

    TemplateMailer.follow_up(communication).deliver_now

    ActiveRecord::Base.transaction do
      communication.update!(status: :sent, sent_at: Time.current)
      scheduled_reminder.update!(status: :sent, sent_at: Time.current)
    end
  rescue StandardError => e
    scheduled_reminder.update!(status: :skipped, skip_reason: e.message.to_s.truncate(255))
    raise
  end
end
