# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin settings", type: :request do
  describe "GET /admin/settings" do
    context "when signed in as an admin" do
      let(:user) { create(:user, role: :admin) }

      before { login_as(user, scope: :user) }

      it "renders application reminder settings" do
        get admin_settings_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Application reminders")
        expect(response.body).to include("Reminder interval")
        expect(response.body).to include("Every 2 weeks")
      end
    end

    describe "PATCH /admin/settings" do
      let(:user) { create(:user, role: :admin) }

      before { login_as(user, scope: :user) }

      it "persists reminder interval weeks" do
        patch admin_settings_path, params: { application_reminder_interval_weeks: "8" }

        expect(response).to redirect_to("#{admin_settings_path}#application-reminders")
        expect(SystemSetting.get("application_reminder_interval_weeks")).to eq(8)
      end

      it "rejects invalid intervals" do
        patch admin_settings_path, params: { application_reminder_interval_weeks: "999" }

        expect(SystemSetting.get("application_reminder_interval_weeks")).to eq(2)
      end
    end

    context "when signed in as staff" do
      let(:user) { create(:user, :staff) }

      before { login_as(user, scope: :user) }

      it "redirects away and does not render settings" do
        get admin_settings_path

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("You are not authorized to view that page.")
      end

      it "cannot update settings" do
        patch admin_settings_path, params: { application_reminder_interval_weeks: "4" }

        expect(response).to redirect_to(root_path)
        expect(SystemSetting.find_by(key: "application_reminder_interval_weeks")).to be_nil
      end
    end
  end
end
