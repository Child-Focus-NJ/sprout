# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mailchimp::TransactionalClient do
  describe "#send_sms" do
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
