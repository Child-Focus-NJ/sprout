# frozen_string_literal: true

RSpec.shared_context "Mailchimp email enabled" do
  around do |example|
    keys = %w[SPROUT_EMAIL_MAILCHIMP_ENABLED API_GATEWAY_URL API_GATEWAY_URL_FILE]
    previous = keys.to_h { |key| [ key, ENV[key] ] }
    ENV["SPROUT_EMAIL_MAILCHIMP_ENABLED"] = "true"
    ENV["API_GATEWAY_URL"] = "http://gateway.test"
    ENV.delete("API_GATEWAY_URL_FILE")
    example.run
  ensure
    previous.each { |key, value| ENV[key] = value }
  end
end

RSpec.shared_context "Mailchimp email provider" do
  include_context "Mailchimp email enabled"

  let(:email_client) { instance_double(Aws::LambdaClient) }
  let(:email_status) { "sent" }

  before do
    SystemSetting.set("application_url", "https://example.org/apply")
    allow(Aws::LambdaClient).to receive(:new).and_return(email_client)
    allow(email_client).to receive(:send_email) do |to:, subject:, text_body:|
      { "status" => email_status, "external_id" => "spec-email-id", "to" => to }
    end
  end
end
