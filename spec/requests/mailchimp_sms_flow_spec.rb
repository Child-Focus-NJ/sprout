# frozen_string_literal: true

require "rails_helper"
require_relative "../../lambdas/mailchimp_realtime/handler"

RSpec.describe "SMS request through Rails and the Lambda handler", type: :request do
  include_context "Mailchimp SMS enabled"

  around do |example|
    previous = %w[MAILCHIMP_API_KEY MAILCHIMP_SMS_FROM].to_h { |key| [ key, ENV[key] ] }
    ENV["MAILCHIMP_API_KEY"] = "MAILCHIMP_API_KEY"
    ENV["MAILCHIMP_SMS_FROM"] = "+12015550100"
    example.run
  ensure
    previous.each { |key, value| ENV[key] = value }
  end

  it "persists and displays a documented provider result across all application layers" do
    user = create(:user)
    volunteer = create(:volunteer, phone: "2015550123")
    login_as(user, scope: :user)

    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:new).and_return(http)
    %i[use_ssl= open_timeout= read_timeout= write_timeout= max_retries=].each { |method| allow(http).to receive(method) }
    provider_response = Net::HTTPOK.new("1.1", "200", "OK")
    allow(provider_response).to receive(:body).and_return(JSON.generate([
      { to: "+12015550123", from: "+12015550100", status: "sent", _id: "spec-flow-id" }
    ]))
    expect(http).to receive(:request) do |request|
      payload = JSON.parse(request.body)
      expect(payload.dig("message", "sms")).to include("to" => [ "+12015550123" ], "text" => "Session reminder", "consent" => "onetime")
      provider_response
    end
    expect(HTTParty).to receive(:post).with("http://gateway.test/mailchimp/send-sms", anything) do |_url, options|
      result = MailchimpRealtime.handler(
        event: { "path" => "/mailchimp/send-sms", "body" => options[:body] },
        context: double(aws_request_id: "spec-flow")
      )
      expect(result[:statusCode]).to eq(200)
      double(success?: true, body: result[:body])
    end

    post send_sms_volunteer_path(volunteer), params: { message: "Session reminder", consent: "onetime" }
    expect(response).to redirect_to(volunteer_path(volunteer))
    expect(volunteer.communications.last).to have_attributes(status: "sent", external_id: "spec-flow-id", sms_consent: "onetime")
    follow_redirect!
    expect(response.body).to include("Session reminder", "spec-flow-id")
  end
end
