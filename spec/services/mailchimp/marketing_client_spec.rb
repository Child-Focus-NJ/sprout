# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mailchimp::MarketingClient do
  describe "#list_campaigns" do
    it "raises when API key is missing" do
      expect do
        described_class.new(api_key: "")
      end.to raise_error(Mailchimp::MarketingClient::ConfigurationError, /MAILCHIMP_MARKETING_API_KEY/)
    end

    it "reads MAILCHIMP_MARKETING_API_KEY and not the transactional key" do
      previous_marketing = ENV["MAILCHIMP_MARKETING_API_KEY"]
      previous_transactional = ENV["MAILCHIMP_API_KEY"]
      ENV["MAILCHIMP_MARKETING_API_KEY"] = "abc123-us2"
      ENV["MAILCHIMP_API_KEY"] = "transactional-key"
      allow(Rails.application.credentials).to receive(:dig).with(:mailchimp, :marketing_api_key).and_return(nil)

      client = described_class.new
      response = instance_double(HTTParty::Response, success?: true, body: { "campaigns" => [], "total_items" => 0 }.to_json)
      allow(HTTParty).to receive(:get).and_return(response)

      client.list_campaigns

      expect(HTTParty).to have_received(:get).with(
        "https://us2.api.mailchimp.com/3.0/campaigns",
        hash_including(basic_auth: { username: "anystring", password: "abc123-us2" })
      )
    ensure
      ENV["MAILCHIMP_MARKETING_API_KEY"] = previous_marketing
      ENV["MAILCHIMP_API_KEY"] = previous_transactional
    end

    it "wraps a timeout as an API error" do
      client = described_class.new(api_key: "abc123-us2")
      allow(HTTParty).to receive(:get).and_raise(Timeout::Error)

      expect { client.list_campaigns }.to raise_error(
        Mailchimp::MarketingClient::ApiError,
        "Mailchimp Marketing API /campaigns could not be reached (Timeout::Error)"
      )
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
