class AttendanceMailer < ApplicationMailer
  def application_queued(to_email)
    # Keep this mail minimal: no template/layout render dependencies.
    mail(
      to: to_email,
      subject: "Application queued",
      body: "Thanks for attending. Your application has been queued."
    )
  end
end

