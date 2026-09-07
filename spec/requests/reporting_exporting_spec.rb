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
      expect(response.body).to include("Reporting")
    end
  end

  describe "POST /reporting_exporting/export_report" do
    it "exports a PDF report of information session sign-ups by year" do
      post export_report_reporting_exporting_index_path, params: {
        "y-axis" => "information session sign-ups",
        "Start Date" => "01/01/2024",
        "End Date" => "12/31/2026",
        "Title" => "sign-ups24-26",
        "report format" => "PDF",
        commit: "Create Report"
      }

      expect(response).to have_http_status(:ok)
      expect(Rails.root.join("tmp", "test_downloads", "sign-ups24-26.pdf")).to exist
    end

    it "exports a PDF report of applications by year" do
      post export_report_reporting_exporting_index_path, params: {
        "y-axis" => "applications",
        "Start Date" => "01/01/2024",
        "End Date" => "12/31/2026",
        "Title" => "applications24-26",
        "report format" => "PDF",
        commit: "Create Report"
      }

      expect(response).to have_http_status(:ok)
      expect(Rails.root.join("tmp", "test_downloads", "applications24-26.pdf")).to exist
    end

    it "redirects with an alert when parameters are invalid" do
      post export_report_reporting_exporting_index_path, params: {
        "Start Date" => "",
        "End Date" => "",
        commit: "Create Report"
      }

      expect(response).to redirect_to(reporting_exporting_index_path)
    end

    it "redirects with an alert when Start Date is after End Date" do
      post export_report_reporting_exporting_index_path, params: {
        "y-axis" => "applications",
        "Start Date" => "12/31/2026",
        "End Date" => "01/01/2024",
        "Title" => "backwards-range",
        "report format" => "PDF",
        commit: "Create Report"
      }

      expect(response).to redirect_to(reporting_exporting_index_path)
      follow_redirect!
      expect(response.body).to include("Start Date cannot be after End Date")
      expect(Rails.root.join("tmp", "test_downloads", "backwards-range.pdf")).not_to exist
    end

    it "counts only within the requested sub-year date range, not the whole year" do
      create(:volunteer, inquiry_date: Date.new(2026, 3, 1))
      create(:volunteer, inquiry_date: Date.new(2026, 3, 15))
      create(:volunteer, inquiry_date: Date.new(2026, 1, 10))

      post export_report_reporting_exporting_index_path, params: {
        "y-axis" => "information session sign-ups",
        "Start Date" => "02/01/2026",
        "End Date" => "04/30/2026",
        "Title" => "feb-apr-2026",
        "report format" => "PDF",
        commit: "Create Report"
      }

      expect(response).to have_http_status(:ok)
      pdf_path = Rails.root.join("tmp", "test_downloads", "feb-apr-2026.pdf")
      expect(pdf_path).to exist

      text = PDF::Reader.new(pdf_path).pages.map(&:text).join(" ")
      expect(text).to include("Feb 1 - Apr 30, 2026")

      numbers = text.scan(/\d+/)
      expect(numbers).to include("2")
      expect(numbers).not_to include("3")
    end

    it "splits a multi-year range into windows anchored to Start Date, with the last window running through End Date" do
      create(:volunteer, inquiry_date: Date.new(2024, 3, 1))
      create(:volunteer, inquiry_date: Date.new(2026, 3, 1))
      create(:volunteer, inquiry_date: Date.new(2026, 6, 1))

      post export_report_reporting_exporting_index_path, params: {
        "y-axis" => "information session sign-ups",
        "Start Date" => "07/02/2023",
        "End Date" => "07/02/2026",
        "Title" => "anchored-3yr",
        "report format" => "PDF",
        commit: "Create Report"
      }

      expect(response).to have_http_status(:ok)
      pdf_path = Rails.root.join("tmp", "test_downloads", "anchored-3yr.pdf")
      expect(pdf_path).to exist

      text = PDF::Reader.new(pdf_path).pages.map(&:text).join(" ")
      expect(text).to include("Jul 2, 2023 - Jul 1, 2024")
      expect(text).to include("Jul 2, 2024 - Jul 1, 2025")
      expect(text).to include("Jul 2, 2025 - Jul 2, 2026")
    end
  end
end
