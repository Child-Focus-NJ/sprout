# frozen_string_literal: true

module Email
  ENABLED_ENV_KEY = "SPROUT_EMAIL_MAILCHIMP_ENABLED"
  DISABLED_MESSAGE = "Email sending is not enabled. Contact your administrator."

  # Switch for staff-sent email. Off unless set, so a QA environment never
  # emails real volunteers by accident.
  def self.sending_enabled?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch(ENABLED_ENV_KEY, "false"))
  end
end
