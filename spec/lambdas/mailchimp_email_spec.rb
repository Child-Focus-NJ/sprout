# frozen_string_literal: true

require "spec_helper"
require_relative "../../lambdas/mailchimp_realtime/handler"

RSpec.describe "Mailchimp email Lambda" do
  let(:body) { { "to" => "volunteer@example.org", "subject" => "Hello", "text_body" => "A message" } }
  let(:http) { instance_double(Net::HTTP) }
  let(:provider_response) { Net::HTTPOK.new("1.1", "200", "OK") }
  let(:result) { { "email" => body["to"], "status" => "sent", "_id" => "email-id" } }

  around do |example|
    previous = %w[MAILCHIMP_API_KEY MAILCHIMP_EMAIL_FROM].to_h { |key| [ key, ENV[key] ] }
    ENV["MAILCHIMP_API_KEY"] = "test-key"
    ENV["MAILCHIMP_EMAIL_FROM"] = "sender@example.org"
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

  def invoke(payload = JSON.generate(body))
    MailchimpRealtime.handler(event: { "path" => "/mailchimp/send-email", "body" => payload }, context: double(aws_request_id: "spec-email"))
  end

  it "sends the documented email payload using the configured sender" do
    body["from_email"] = "untrusted@example.org"
    expect(invoke[:statusCode]).to eq(200)
    expect(http).to have_received(:request) do |request|
      expect(request.path).to eq("/api/1.4/messages/send")
      expect(JSON.parse(request.body)).to eq(
        "key" => "test-key", "message" => {
          "from_email" => "sender@example.org", "to" => [ { "email" => body["to"], "type" => "to" } ],
          "subject" => "Hello", "text" => "A message", "merge" => false
        }
      )
    end
    expect(http).to have_received(:max_retries=).with(0)
  end

  %w[sent queued scheduled rejected invalid].each do |status|
    it "preserves a #{status} result" do
      result.merge!("status" => status, "reject_reason" => "unsub")
      expect(JSON.parse(invoke[:body])).to include("status" => status, "to" => body["to"], "external_id" => "email-id", "reject_reason" => "unsub")
    end
  end

  %w[MAILCHIMP_API_KEY MAILCHIMP_EMAIL_FROM].each do |key|
    it "rejects missing #{key} before making a request" do
      ENV.delete(key)
      expect(invoke[:statusCode]).to eq(503)
      expect(http).not_to have_received(:request)
    end
  end

  it "rejects malformed requests and an invalid sender" do
    [ "{", "[]", "null", JSON.generate(body.merge("to" => "invalid")),
      JSON.generate(body.merge("subject" => "x" * 999)), JSON.generate(body.merge("subject" => "Hello\nBcc: evil@example.org")),
      JSON.generate(body.merge("text_body" => " ")) ].each do |payload|
      expect(invoke(payload)[:statusCode]).to eq(400)
    end
    ENV["MAILCHIMP_EMAIL_FROM"] = "invalid"
    expect(invoke[:statusCode]).to eq(503)
    expect(http).not_to have_received(:request)
  end

  it "does not accept malformed or mismatched provider results" do
    [ "not JSON", "{}", "[]", JSON.generate([ result, result ]), JSON.generate([ result.except("_id") ]),
      JSON.generate([ result.merge("email" => "other@example.org") ]), JSON.generate([ result.merge("status" => "ok") ]) ].each do |payload|
      allow(provider_response).to receive(:body).and_return(payload)
      expect(invoke[:statusCode]).to eq(502)
    end
  end

  it "reports HTTP failures without exposing provider details" do
    [ [ Net::HTTPUnauthorized, "401", 422 ], [ Net::HTTPInternalServerError, "500", 502 ] ].each do |klass, code, expected|
      response = klass.new("1.1", code, "Error")
      allow(response).to receive(:body).and_return("test-key private data")
      allow(http).to receive(:request).and_return(response)
      outcome = invoke
      expect(outcome[:statusCode]).to eq(expected)
      expect(outcome[:body]).not_to include("test-key", "private data")
    end
  end

  it "reports timeouts as uncertain and makes no automatic retry" do
    allow(http).to receive(:request).and_raise(Net::ReadTimeout)
    expect(invoke[:statusCode]).to eq(502)
    expect(http).to have_received(:request).once
  end
end
