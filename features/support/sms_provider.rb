# frozen_string_literal: true

require "rspec/mocks"

World(RSpec::Mocks::ExampleMethods)

Before("@sms_send") do
  @sms_previous_env = ENV["SPROUT_SMS_MAILCHIMP_ENABLED"]
  ENV["SPROUT_SMS_MAILCHIMP_ENABLED"] = "true"
  RSpec::Mocks.setup
  client = instance_double(Aws::LambdaClient)
  allow(Aws::LambdaClient).to receive(:new).and_return(client)
  allow(client).to receive(:send_sms) do |to:, message:, consent:|
    { "status" => "sent", "external_id" => "cucumber-sms-id", "to" => to }
  end
end

After("@sms_send") do
  RSpec::Mocks.verify
ensure
  RSpec::Mocks.teardown
  ENV["SPROUT_SMS_MAILCHIMP_ENABLED"] = @sms_previous_env
end
