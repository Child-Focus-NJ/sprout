# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin usage reports", type: :request do
  describe "GET /admin/usage_report" do
    context "when signed in as an admin" do
      let(:user) { create(:user, role: :admin) }

      before { login_as(user, scope: :user) }

      it "shows the sign-in, data volume, and communication headline numbers" do
        SignInLog.create!(user: user)
        create(:volunteer)
        create(:information_session)

        get admin_usage_report_path

        expect(response).to have_http_status(:ok)
        tile_text = ->(id) { response.parsed_body.at_css("##{id}").text.squish }
        expect(tile_text.call("stat-sign-ins")).to include("Sign-ins 1", "1 this month")
        expect(tile_text.call("stat-data-volume")).to include("Volunteers 1", "1 info sessions · 0 notes")
        expect(tile_text.call("stat-communications")).to include("Communications sent 0", "0 email · 0 SMS")
      end

      it "lists recent sign-ins by user" do
        SignInLog.create!(user: user, ip_address: "127.0.0.1")

        get admin_usage_report_path

        panel = response.parsed_body.at_css("#recent-sign-ins").text.squish
        expect(panel).to include(user.display_name, user.email, "127.0.0.1")
      end

      it "explains when there's nothing to show yet" do
        get admin_usage_report_path

        expect(response.body).to include("No sign-ins recorded yet.")
      end
    end

    context "when signed in as a non-admin user" do
      let(:user) { create(:user) }

      before { login_as(user, scope: :user) }

      it "redirects away" do
        get admin_usage_report_path

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("You are not authorized to view that page.")
      end
    end

    context "when signed out" do
      it "redirects to the login page" do
        get admin_usage_report_path

        expect(response).to redirect_to(login_path)
      end
    end
  end
end
