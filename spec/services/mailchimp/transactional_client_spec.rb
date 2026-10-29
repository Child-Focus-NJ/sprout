# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mailchimp::TransactionalClient do
  describe "environment configuration" do
    include_context "Mailchimp SMS enabled"

    it "uses the configured account key and sender for each deployment" do
      response = instance_double(HTTParty::Response, success?: true,
        body: [ { "status" => "sent", "_id" => "id", "to" => "+12015550123" } ].to_json)
      allow(described_class).to receive(:post).and_return(response)
      ENV["MAILCHIMP_API_KEY"] = "marketing-key-us1"
      { "local-testing-key" => "+12015550101", "production-key" => "+12015550102" }.each do |key, sender|
        ENV["MANDRILL_API_KEY"] = key
        ENV["MANDRILL_SMS_FROM"] = sender
        described_class.new.send_sms(to: "+12015550123", message: "Hello", consent: "onetime")
        expect(described_class).to have_received(:post).with("/messages/send-sms", hash_including(
          body: { key: key, message: { sms: { to: [ "+12015550123" ], from: sender, text: "Hello", consent: "onetime" } } }.to_json
        ))
      end
    end
  end

  describe "#send_sms" do
    def send_with_response(payload, http_code: 200)
      response = instance_double(HTTParty::Response, success?: http_code == 200, code: http_code, body: payload.to_json)
      allow(described_class).to receive(:post).and_return(response)
      described_class.new(api_key: "test-key").send_sms(to: "+12015550123", message: "Hello", consent: "onetime", from: "+12015550100")
    end

    it "accepts harmless recipient spacing and returns the canonical number" do
      result = send_with_response([ { "status" => "sent", "_id" => "abc", "to" => "+1 201 555 0123" } ])
      expect(result).to include("to" => "+12015550123", "status" => "sent")
    end

    it "accepts punctuation in a successful recipient instead of treating the send as uncertain" do
      result = send_with_response([ { "status" => "sent", "_id" => "abc", "to" => "+1 (201) 555-0123" } ])
      expect(result).to include("to" => "+12015550123", "status" => "sent", "external_id" => "abc")
    end

    it "keeps a different recipient uncertain instead of accepting it" do
      expect do
        send_with_response([ { "status" => "sent", "_id" => "abc", "to" => "+1 201 555 9999" } ])
      end.to raise_error(described_class::UncertainDeliveryError)
    end

    it "treats a server failure as uncertain and never retries" do
      expect { send_with_response({}, http_code: 502) }.to raise_error(described_class::UncertainDeliveryError)
      expect(described_class).to have_received(:post).once
    end

    it "reports a definitive client error without echoing provider details" do
      expect { send_with_response({ "message" => "secret" }, http_code: 401) }.to raise_error(described_class::ApiError, /HTTP 401/)
    end

    it "raises when API key is missing" do
      expect do
        described_class.new(api_key: "")
      end.to raise_error(Mailchimp::TransactionalClient::ConfigurationError)
    end

    it "POSTs to Mandrill v1.4 send-sms and normalizes the result" do
      client = described_class.new(api_key: "mandrill-key")
      response = instance_double(
        HTTParty::Response,
        success?: true,
        body: [ { "status" => "sent", "_id" => "abc", "to" => "+12015550123" } ].to_json
      )
      allow(described_class).to receive(:post).and_return(response)

      result = client.send_sms(
        to: "+12015550123",
        message: "Hello",
        consent: "onetime",
        from: "+15557654321"
      )

      expect(result).to eq(
        "status" => "sent",
        "external_id" => "abc",
        "to" => "+12015550123",
        "reject_reason" => nil
      )
      expect(described_class).to have_received(:post).with(
        "/messages/send-sms",
        hash_including(body: a_string_including("mandrill-key", "+12015550123", "Hello", "onetime"))
      )
    end
  end
end
