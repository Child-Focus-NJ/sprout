# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mailchimp::TransactionalClient do
  let(:client) { described_class.new(api_key: "test-key") }
  let(:recipient) { "tester@example.org" }

  describe "#send_email" do
    it "sends plain text from the configured domain and retains the provider ID" do
      response = instance_double(HTTParty::Response, success?: true,
        body: [ { "email" => recipient, "_id" => "email-id", "status" => "sent" } ].to_json)
      allow(described_class).to receive(:post).and_return(response)
      result = client.send_email(to: recipient, subject: "Test", text_body: "Hello", from_email: "sprout@example.org")
      expect(result).to include("status" => "sent", "external_id" => "email-id", "to" => recipient)
      expect(described_class).to have_received(:post) do |path, options|
        expect(path).to eq("/messages/send")
        expect(JSON.parse(options[:body])).to eq(
          "key" => "test-key", "message" => {
            "from_email" => "sprout@example.org", "to" => [ { "email" => recipient, "type" => "to" } ],
            "subject" => "Test", "text" => "Hello", "merge" => false
          }
        )
      end
    end

    it "treats a server error as uncertain so applications cannot be sent twice" do
      allow(described_class).to receive(:post).and_return(instance_double(HTTParty::Response, success?: false, code: 502))
      expect { client.send_email(to: recipient, subject: "Test", text_body: "Hello", from_email: "sprout@example.org") }
        .to raise_error(described_class::UncertainDeliveryError)
    end
  end

  describe "#email_info" do
    let(:payload) { { "_id" => "email-id", "email" => recipient, "state" => "sent", "ts" => 1_790_000_000 } }

    before do
      allow(described_class).to receive(:post) do
        instance_double(HTTParty::Response, success?: true, body: payload.to_json)
      end
    end

    it "reads the existing message and its provider send time" do
      expect(client.email_info(id: "email-id", to: recipient)).to eq(
        "status" => "sent", "sent_at" => Time.at(payload["ts"]).utc
      )
      expect(described_class).to have_received(:post).with("/messages/info",
        hash_including(body: { key: "test-key", id: "email-id" }.to_json))
    end

    [ [ "_id", "another-id" ], [ "email", "another@example.org" ], [ "state", "unknown" ], [ "ts", nil ] ].each do |key, value|
      it "rejects mismatched or incomplete status data for #{key}" do
        payload[key] = value
        expect { client.email_info(id: "email-id", to: recipient) }.to raise_error(described_class::UncertainDeliveryError)
      end
    end

    it "does not interpret an unavailable message as a rejection" do
      allow(described_class).to receive(:post).and_return(instance_double(HTTParty::Response, success?: false, code: 404))
      expect { client.email_info(id: "email-id", to: recipient) }.to raise_error(described_class::ApiError)
    end
  end
end
