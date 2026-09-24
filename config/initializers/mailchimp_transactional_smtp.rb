# frozen_string_literal: true

# When MANDRILL_API_KEY is present, route ActionMailer through Mandrill SMTP
# (transactional email). Test env always stays on :test.
#
# SMTP username must be a registered email on the Mandrill/Transactional account.
# SMTP password is the Transactional API key.
if !Rails.env.test? && ENV["MANDRILL_API_KEY"].present?
  Rails.application.configure do
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.raise_delivery_errors = true
    config.action_mailer.smtp_settings = {
      address: "smtp.mandrillapp.com",
      port: 587,
      user_name: ENV.fetch("MANDRILL_SMTP_USERNAME") { ENV.fetch("MANDRILL_FROM_EMAIL", "noreply@childfocusnj.org") },
      password: ENV["MANDRILL_API_KEY"],
      authentication: :plain,
      enable_starttls_auto: true
    }
  end
end
