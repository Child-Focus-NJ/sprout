# frozen_string_literal: true

require "rails_helper"
require_relative "../../lambdas/mailchimp_realtime/handler"

RSpec.describe "Email request through Rails and Lambda", type: :request do
  include_context "Mailchimp email enabled"
  let(:volunteer) { create(:volunteer) }
  let(:http) { instance_double(Net::HTTP) }

  around do |example|
    previous = %w[MAILCHIMP_API_KEY MAILCHIMP_EMAIL_FROM].to_h { |key| [ key, ENV[key] ] }
    ENV["MAILCHIMP_API_KEY"] = "test-key"
    ENV["MAILCHIMP_EMAIL_FROM"] = "sender@example.org"
    example.run
  ensure
    previous.each { |key, value| ENV[key] = value }
  end

  before do
    login_as(create(:user), scope: :user)
    allow(Net::HTTP).to receive(:new).and_return(http)
    %i[use_ssl= open_timeout= read_timeout= write_timeout= max_retries=].each { |method| allow(http).to receive(method) }
    allow(HTTParty).to receive(:post).with("http://gateway.test/mailchimp/send-email", anything) do |_url, options|
      result = MailchimpRealtime.handler(
        event: { "path" => "/mailchimp/send-email", "body" => options[:body] }, context: double(aws_request_id: "spec-email")
      )
      double(success?: result[:statusCode] == 200, code: result[:statusCode], body: result[:body])
    end
  end

  it "sends through every application layer and displays the provider ID" do
    provider_response = Net::HTTPOK.new("1.1", "200", "OK")
    allow(provider_response).to receive(:body).and_return(JSON.generate([ { email: volunteer.email, status: "sent", _id: "flow-id" } ]))
    expect(http).to receive(:request) do |request|
      expect(JSON.parse(request.body).fetch("message")).to include(
        "from_email" => "sender@example.org", "subject" => "Details", "text" => "Your message",
        "to" => [ { "email" => volunteer.email, "type" => "to" } ]
      )
      provider_response
    end
    post send_email_volunteer_path(volunteer), params: { subject: "Details", message: "Your message" }
    expect(response).to redirect_to(volunteer_path(volunteer))
    expect(volunteer.communications.last).to have_attributes(status: "sent", external_id: "flow-id")
    follow_redirect!
    expect(response.body).to include("flow-id", "Your message", "Email sent to Mailchimp")
  end

  it "preserves the draft and records uncertainty when the provider times out" do
    allow(http).to receive(:request).and_raise(Net::ReadTimeout)
    post send_email_volunteer_path(volunteer), params: { subject: "Details", message: "Your message" }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("before resending", "Your message")
    expect(volunteer.communications.last).to have_attributes(status: "pending", sent_at: nil)
    expect(http).to have_received(:request).once
  end
end
