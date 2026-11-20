# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Main navigation", type: :request do
  let(:user) { create(:user) }

  before { login_as(user, scope: :user) }

  def vms_link
    response.parsed_body.css("nav.app-navbar__links a").find { |a| a.text.strip.start_with?("VMS") }
  end

  it "links to the external VMS in a new tab" do
    get application_dashboard_path

    expect(vms_link).to be_present
    expect(vms_link["href"]).to eq(ApplicationHelper::DEFAULT_VMS_URL)
    expect(vms_link["target"]).to eq("_blank")
    expect(vms_link["rel"]).to eq("noopener noreferrer")
  end

  it "uses EXTERNAL_VMS_URL when it is set" do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch)
      .with(ApplicationHelper::VMS_URL_ENV_KEY, anything)
      .and_return("https://vms.example.org/")

    get application_dashboard_path

    expect(vms_link["href"]).to eq("https://vms.example.org")
  end
end
