# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mailchimp::MarketingClient do
  describe "#list_campaigns" do
    it "raises when API key is missing" do
      expect do
        described_class.new(api_key: "")
      end.to raise_error(Mailchimp::MarketingClient::ConfigurationError)
    end

    it "GETs campaigns from the Marketing API" do
      client = described_class.new(api_key: "abc123-us2")
      response = instance_double(
        HTTParty::Response,
        success?: true,
        body: { "campaigns" => [ { "id" => "c1", "settings" => { "title" => "Test" } } ], "total_items" => 1 }.to_json
      )
      allow(HTTParty).to receive(:get).and_return(response)

      result = client.list_campaigns(count: 10)

      expect(result["total_items"]).to eq(1)
      expect(result["campaigns"].first["id"]).to eq("c1")
      expect(HTTParty).to have_received(:get).with(
        "https://us2.api.mailchimp.com/3.0/campaigns",
        hash_including(basic_auth: { username: "anystring", password: "abc123-us2" })
      )
    end
  end
end
