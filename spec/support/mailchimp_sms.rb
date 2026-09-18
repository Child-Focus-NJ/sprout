# frozen_string_literal: true

RSpec.shared_context "Mailchimp SMS enabled" do
  around do |example|
    keys = %w[SPROUT_SMS_MAILCHIMP_ENABLED API_GATEWAY_URL API_GATEWAY_URL_FILE]
    previous = keys.to_h { |key| [ key, ENV[key] ] }
    ENV["SPROUT_SMS_MAILCHIMP_ENABLED"] = "true"
    ENV["API_GATEWAY_URL"] = "http://gateway.test"
    ENV.delete("API_GATEWAY_URL_FILE")
    example.run
  ensure
    previous.each { |key, value| ENV[key] = value }
  end
end
