# frozen_string_literal: true

RSpec.shared_context "Mailchimp SMS enabled" do
  around do |example|
    keys = %w[
      SPROUT_SMS_MAILCHIMP_ENABLED
      MANDRILL_API_KEY
      MANDRILL_SMS_FROM
      MAILCHIMP_API_KEY
      MAILCHIMP_SMS_FROM
      API_GATEWAY_URL
      API_GATEWAY_URL_FILE
    ]
    previous = keys.to_h { |key| [ key, ENV[key] ] }
    ENV["SPROUT_SMS_MAILCHIMP_ENABLED"] = "true"
    ENV["MANDRILL_API_KEY"] = "test-mandrill-key"
    ENV["MANDRILL_SMS_FROM"] = "+12015550100"
    # Keep gateway URL for Aws::LambdaClient specs (Zoom/VMS/legacy paths still use it).
    ENV["API_GATEWAY_URL"] = "http://gateway.test"
    ENV.delete("API_GATEWAY_URL_FILE")
    example.run
  ensure
    previous.each { |key, value| ENV[key] = value }
  end
end
