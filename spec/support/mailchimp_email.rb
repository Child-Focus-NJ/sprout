# frozen_string_literal: true

RSpec.shared_context "Mailchimp email enabled" do
  around do |example|
    keys = %w[SPROUT_EMAIL_MAILCHIMP_ENABLED MANDRILL_API_KEY MANDRILL_FROM_EMAIL MAILCHIMP_API_KEY MAILCHIMP_EMAIL_FROM]
    previous = keys.to_h { |key| [ key, ENV[key] ] }
    ENV["SPROUT_EMAIL_MAILCHIMP_ENABLED"] = "true"
    ENV["MANDRILL_API_KEY"] = "test-mandrill-key"
    ENV["MANDRILL_FROM_EMAIL"] = "noreply@example.org"
    example.run
  ensure
    previous.each { |key, value| ENV[key] = value }
  end
end

RSpec.shared_context "Mailchimp email provider" do
  include_context "Mailchimp email enabled"

  let(:email_client) { instance_double(Mailchimp::TransactionalClient) }
  let(:email_status) { "sent" }

  before do
    SystemSetting.set("application_url", "https://example.org/apply")
    allow(Mailchimp::TransactionalClient).to receive(:new).and_return(email_client)
    allow(email_client).to receive(:send_email) do |to:, subject:, text_body:|
      { "status" => email_status, "external_id" => "spec-email-id", "to" => to }
    end
  end
end
