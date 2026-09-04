# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reporting and exporting", type: :request do
  let(:user) { create(:user) }

  before do
    login_as(user, scope: :user)
    FileUtils.mkdir_p(Rails.root.join("tmp", "test_downloads"))
  end

  after do
    FileUtils.rm_f(Dir[Rails.root.join("tmp", "test_downloads", "*")])
  end

  describe "GET /reporting_exporting" do
    it "renders the reporting and exporting page" do
      get reporting_exporting_index_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Reporting & Exporting")
    end
  end

  describe "POST /reporting_exporting/export_report" do
    it "exports a PDF report of information session sign-ups by year" do
      post export_report_reporting_exporting_index_path, params: {
        "x-axis" => "years",
        "y-axis" => "information session sign-ups",
        "Start Date" => "01/01/2024",
        "End Date" => "12/31/2026",
        "Title" => "sign-ups24-26",
        "report format" => "PDF",
        commit: "Export Report"
      }

      expect(response).to have_http_status(:ok)
      expect(Rails.root.join("tmp", "test_downloads", "sign-ups24-26.pdf")).to exist
    end

    it "exports a PDF report of applications by year" do
      post export_report_reporting_exporting_index_path, params: {
        "x-axis" => "years",
        "y-axis" => "applications",
        "Start Date" => "01/01/2024",
        "End Date" => "12/31/2026",
        "Title" => "applications24-26",
        "report format" => "PDF",
        commit: "Export Report"
      }

      expect(response).to have_http_status(:ok)
      expect(Rails.root.join("tmp", "test_downloads", "applications24-26.pdf")).to exist
    end

    it "redirects with an alert when parameters are invalid" do
      post export_report_reporting_exporting_index_path, params: {
        "x-axis" => "years",
        "Start Date" => "",
        "End Date" => "",
        commit: "Export Report"
      }

      expect(response).to redirect_to(reporting_exporting_index_path)
    end
  end
end
