# frozen_string_literal: true

require "rspec/mocks"

World(RSpec::Mocks::ExampleMethods)

Before("@email_send") do
  @email_previous_env = ENV["SPROUT_EMAIL_MAILCHIMP_ENABLED"]
  ENV["SPROUT_EMAIL_MAILCHIMP_ENABLED"] = "true"
  SystemSetting.set("application_url", "https://example.org/apply")
  @email_provider_status = "sent"
  RSpec::Mocks.setup
  client = instance_double(Aws::LambdaClient)
  allow(Aws::LambdaClient).to receive(:new).and_return(client)
  allow(client).to receive(:send_email) do |to:, subject:, text_body:|
    { "status" => @email_provider_status, "external_id" => "cucumber-email-id", "to" => to }
  end
end

After("@email_send") do
  RSpec::Mocks.verify
ensure
  RSpec::Mocks.teardown
  ENV["SPROUT_EMAIL_MAILCHIMP_ENABLED"] = @email_previous_env
end
