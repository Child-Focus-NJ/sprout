# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Application dashboard", type: :request do
  describe "GET /application_dashboard" do
    context "when signed in as an admin" do
      let(:user) { create(:user, role: :admin) }

      before { login_as(user, scope: :user) }

      it "shows volunteers awaiting submission in order" do
        older = create(
          :volunteer,
          first_name: "Older",
          last_name: "Queue",
          email: "older.queue@childfocusnj.org",
          current_funnel_stage: :application_sent,
          application_sent_at: 3.days.ago
        )
        newer = create(
          :volunteer,
          first_name: "Newer",
          last_name: "Queue",
          email: "newer.queue@childfocusnj.org",
          current_funnel_stage: :application_sent,
          application_sent_at: 1.day.ago
        )

        get application_dashboard_path

        expect(response).to have_http_status(:ok)
        body = response.body
        expect(body).to include("Awaiting submission")
        expect(body).to include("Application sent")
        expect(body).to include(older.email)
        expect(body).to include("View profile")
        expect(body.index(older.full_name)).to be < body.index(newer.full_name)
      end
    end

    context "when signed in as staff" do
      let(:user) { create(:user, :staff) }

      before { login_as(user, scope: :user) }

      it "redirects away" do
        get application_dashboard_path

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("You are not authorized to view that page.")
      end
    end
  end
end
