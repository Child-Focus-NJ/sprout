class AttendanceMailer < ApplicationMailer
  def application(to_email, application_url:)
    mail(
      to: to_email,
      subject: "Your volunteer application",
      content_type: "text/plain",
      body: "Thank you for your interest in volunteering with Child Focus NJ.\n\nPlease complete your application here:\n#{application_url}"
    )
  end
end
