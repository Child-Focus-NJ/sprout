# frozen_string_literal: true

RSpec.shared_context "Mailchimp SMS enabled" do
  around do |example|
    keys = %w[SPROUT_SMS_MAILCHIMP_ENABLED MANDRILL_API_KEY MANDRILL_SMS_FROM MAILCHIMP_API_KEY MAILCHIMP_SMS_FROM]
    previous = keys.to_h { |key| [ key, ENV[key] ] }
    ENV["SPROUT_SMS_MAILCHIMP_ENABLED"] = "true"
    ENV["MANDRILL_API_KEY"] = "test-mandrill-key"
    ENV["MANDRILL_SMS_FROM"] = "+12015550100"
    example.run
  ensure
    previous.each { |key, value| ENV[key] = value }
  end
end
