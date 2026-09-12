class TemplateMailer < ApplicationMailer
  def follow_up(communication)
    @communication = communication

    mail(
      to: communication.volunteer.email,
      subject: communication.subject.presence || "A note from Child Focus NJ",
      body: communication.body.to_s
    )
  end
end
