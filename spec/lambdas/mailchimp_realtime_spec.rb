# frozen_string_literal: true

require "spec_helper"
require_relative "../../lambdas/mailchimp_realtime/handler"

RSpec.describe MailchimpRealtime do
  let(:context) { double(aws_request_id: "spec-request") }
  let(:body) { { "to" => "+12015550123", "message" => "Test message", "consent" => "onetime" } }
  let(:http) { instance_double(Net::HTTP) }
  let(:provider_response) { Net::HTTPOK.new("1.1", "200", "OK") }
  let(:result) { { "to" => body["to"], "from" => "+12015550100", "status" => "sent", "_id" => "spec-sms-id" } }

  around do |example|
    previous = %w[MAILCHIMP_API_KEY MAILCHIMP_SMS_FROM].to_h { |key| [ key, ENV[key] ] }
    ENV["MAILCHIMP_API_KEY"] = "MAILCHIMP_API_KEY"
    ENV["MAILCHIMP_SMS_FROM"] = "+12015550100"
    example.run
  ensure
    previous.each { |key, value| ENV[key] = value }
  end

  before do
    allow(Net::HTTP).to receive(:new).and_return(http)
    %i[use_ssl= open_timeout= read_timeout= write_timeout= max_retries=].each { |method| allow(http).to receive(method) }
    allow(http).to receive(:request).and_return(provider_response)
    allow(provider_response).to receive(:body) { JSON.generate([ result ]) }
  end

  def invoke(payload = JSON.generate(body), path: "/mailchimp/send-sms")
    described_class.handler(event: { "path" => path, "body" => payload }, context: context)
  end

  it "uses Mailchimp's v1.4 endpoint and documented nested SMS payload" do
    response = invoke
    expect(response[:statusCode]).to eq(200)
    expect(JSON.parse(response[:body])).to include("status" => "sent", "external_id" => "spec-sms-id", "to" => body["to"])
    expect(Net::HTTP).to have_received(:new).with("mandrillapp.com", 443)
    expect(http).to have_received(:request) do |request|
      expect(request.path).to eq("/api/1.4/messages/send-sms")
      expect(JSON.parse(request.body)).to eq(
        "key" => "MAILCHIMP_API_KEY",
        "message" => { "sms" => { "to" => [ body["to"] ], "from" => "+12015550100", "text" => "Test message", "consent" => "onetime" } }
      )
    end
    expect(http).to have_received(:max_retries=).with(0)
  end

  %w[queued scheduled rejected invalid].each do |status|
    it "preserves the #{status} result and provider ID" do
      result.merge!("status" => status, "reject_reason" => "unsub")
      expect(JSON.parse(invoke[:body])).to include("status" => status, "external_id" => "spec-sms-id", "reject_reason" => "unsub")
    end
  end

  %w[MAILCHIMP_API_KEY MAILCHIMP_SMS_FROM].each do |key|
    it "fails explicitly when #{key} is missing" do
      ENV.delete(key)
      expect(invoke[:statusCode]).to eq(503)
      expect(http).not_to have_received(:request)
    end
  end

  it "rejects invalid JSON, non-object bodies, missing consent, invalid numbers, and oversized text" do
    [ "{", "null", "[]", JSON.generate(body.except("consent")),
      JSON.generate(body.merge("to" => "000")), JSON.generate(body.merge("message" => "x" * 321)) ].each do |payload|
      expect(invoke(payload)[:statusCode]).to eq(400)
    end
    expect(http).not_to have_received(:request)
  end

  it "does not report unimplemented email or audience actions as successful" do
    expect(invoke(path: "/mailchimp/send-email")[:statusCode]).to eq(501)
    expect(invoke(path: "/mailchimp/member")[:statusCode]).to eq(501)
    expect(invoke(path: "/mailchimp/unknown")[:statusCode]).to eq(404)
    expect(http).not_to have_received(:request)
  end

  it "rejects malformed or mismatched provider responses" do
    [ "not JSON", "{}", "[]", JSON.generate([ result.merge("to" => "+12015550999") ]),
      JSON.generate([ result.except("_id") ]), JSON.generate([ result.merge("status" => "ok") ]) ].each do |payload|
      allow(provider_response).to receive(:body).and_return(payload)
      expect(invoke[:statusCode]).to eq(502)
    end
  end

  it "reports provider HTTP failures without echoing the response or credential" do
    response = Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized")
    allow(response).to receive(:body).and_return("MAILCHIMP_API_KEY sensitive provider body")
    allow(http).to receive(:request).and_return(response)
    outcome = invoke
    expect(outcome[:statusCode]).to eq(422)
    expect(outcome[:body]).not_to include("MAILCHIMP_API_KEY", "sensitive provider body")
  end

  it "reports a timeout as uncertain without retrying" do
    allow(http).to receive(:request).and_raise(Net::ReadTimeout)
    expect(invoke[:statusCode]).to eq(502)
    expect(http).to have_received(:request).once
  end
end
