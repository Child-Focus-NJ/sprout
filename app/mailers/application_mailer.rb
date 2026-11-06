class ApplicationMailer < ActionMailer::Base
  default from: -> { Mailchimp::TransactionalClient.credential(:from_email, "MANDRILL_FROM_EMAIL", "MAILCHIMP_EMAIL_FROM").presence || "noreply@childfocusnj.org" }
  layout "mailer"
end
