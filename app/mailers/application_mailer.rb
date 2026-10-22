class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV["MANDRILL_FROM_EMAIL"].presence || ENV["MAILCHIMP_EMAIL_FROM"].presence || "noreply@childfocusnj.org" }
  layout "mailer"
end
