# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin campaigns", type: :request do
  let(:admin) { create(:user) }

  before { login_as(admin, scope: :user) }

  describe "GET /admin/campaigns" do
    it "lists campaigns from the Marketing API" do
      client = instance_double(Mailchimp::MarketingClient)
      allow(Mailchimp::MarketingClient).to receive(:new).and_return(client)
      allow(client).to receive(:list_campaigns).and_return(
        "total_items" => 1,
        "campaigns" => [
          {
            "id" => "87c3c5ef3e",
            "status" => "save",
            "type" => "regular",
            "create_time" => "2026-09-24T02:21:54+00:00",
            "settings" => { "title" => "Sprout Testing - 9/23/26", "subject_line" => "CASA Volunteers..." }
          }
        ]
      )

      get admin_campaigns_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sprout Testing - 9/23/26")
      expect(response.body).to include("save")
    end

    it "shows an error when Marketing API is not configured" do
      allow(Mailchimp::MarketingClient).to receive(:new)
        .and_raise(Mailchimp::MarketingClient::ConfigurationError, "MAILCHIMP_API_KEY is not set")

      get admin_campaigns_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Could not load campaigns")
      expect(response.body).to include("MAILCHIMP_API_KEY is not set")
    end
  end
end
