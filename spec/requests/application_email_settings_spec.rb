# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Application email settings", type: :request do
  let(:admin) { create(:user, role: :admin) }

  before { login_as(admin, scope: :user) }

  it "links to settings from Admin and displays the current link" do
    SystemSetting.set("application_url", "https://example.org/apply")
    get system_management_path
    expect(response.body).to include("Application email settings", "#{admin_settings_path}#application-email")
    get admin_settings_path
    expect(response.body).to include('value="https://example.org/apply"', "Save application link")
  end

  it "updates the link and records the admin without changing reminder settings" do
    SystemSetting.set("application_reminder_interval_weeks", 8, type: :integer)
    patch admin_settings_path, params: { application_url: " https://example.org/application?program=volunteer " }
    expect(response).to redirect_to("#{admin_settings_path}#application-email")
    expect(SystemSetting.get("application_url")).to eq("https://example.org/application?program=volunteer")
    expect(SystemSetting.find_by!(key: "application_url").updated_by_user).to eq(admin)
    expect(SystemSetting.get("application_reminder_interval_weeks")).to eq(8)
  end

  it "allows clearing the link to disable application emails" do
    SystemSetting.set("application_url", "https://example.org/apply")
    patch admin_settings_path, params: { application_url: "" }
    expect(response).to have_http_status(:redirect)
    expect(SystemSetting.get("application_url")).to eq("")
  end

  it "rejects unsafe or incomplete URLs without replacing the saved link" do
    SystemSetting.set("application_url", "https://example.org/apply")
    [ "javascript:alert(1)", "https://", "/apply", "https://user:password@example.org/apply", "https://example.org/\napply" ].each do |url|
      patch admin_settings_path, params: { application_url: url }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Application link must be")
      expect(SystemSetting.get("application_url")).to eq("https://example.org/apply")
    end
  end

  it "does not change the link when only reminder settings are saved" do
    SystemSetting.set("application_url", "https://example.org/apply")
    patch admin_settings_path, params: { application_reminder_interval_weeks: "4" }
    expect(SystemSetting.get("application_url")).to eq("https://example.org/apply")
  end

  it "requires admin access to change the link" do
    login_as(create(:user, role: :user), scope: :user)
    patch admin_settings_path, params: { application_url: "https://example.org/apply" }
    expect(response).to redirect_to(root_path)
    expect(SystemSetting.get("application_url")).to be_nil
  end
end
