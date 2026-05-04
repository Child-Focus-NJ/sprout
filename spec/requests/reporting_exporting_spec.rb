# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reporting and exporting", type: :request do
  let(:user) { create(:user) }
  let(:volunteer) { create(:volunteer, email: "sammy123@childfocusnj.org", first_name: "Samantha", last_name: "Ray") }

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

  describe "POST /reporting_exporting/export_data" do
    it "exports volunteer data to Excel filtered by status and date range" do
      volunteer

      post export_data_reporting_exporting_index_path, params: {
        "Title" => "Attendees2024",
        "export format" => "Excel",
        "Status" => "Attended an Information Session",
        "Start Date" => "01/01/2024",
        "End Date" => "12/31/2026",
        commit: "Export Data"
      }

      expect(response).to have_http_status(:ok)
      expect(Rails.root.join("tmp", "test_downloads", "Attendees2024.xlsx")).to exist
    end

    it "includes the volunteer's data in the Excel file" do
      volunteer.update!(first_session_attended_at: Date.new(2024, 6, 1))
      session = create(:information_session, scheduled_at: 1.week.from_now)
      create(:session_registration, volunteer: volunteer, information_session: session)

      post export_data_reporting_exporting_index_path, params: {
        "Title" => "Attendees2024",
        "export format" => "Excel",
        "Status" => "Attended an Information Session",
        "Start Date" => "01/01/2024",
        "End Date" => "12/31/2026",
        commit: "Export Data"
      }

      xlsx_path = Rails.root.join("tmp", "test_downloads", "Attendees2024.xlsx")
      expect(xlsx_path).to exist

      workbook = Roo::Spreadsheet.open(xlsx_path.to_s)
      sheet_data = workbook.sheet(0).to_a.flatten
      expect(sheet_data).to include("Samantha Ray")
      expect(sheet_data).to include("sammy123@childfocusnj.org")
      expect(sheet_data).to include("Attended an Information Session")
    end
  end
end
