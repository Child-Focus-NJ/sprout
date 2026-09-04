require "rails_helper"

RSpec.describe "SystemManagement", type: :request do
  let(:admin) { create(:user, role: :admin) }
  let(:volunteer) { create(:volunteer, email: "sammy123@childfocusnj.org", first_name: "Samantha", last_name: "Ray") }

  before do
    login_as(admin, scope: :user)
    FileUtils.mkdir_p(Rails.root.join("tmp", "test_downloads"))
  end

  after do
    FileUtils.rm_f(Dir[Rails.root.join("tmp", "test_downloads", "*")])
  end

  describe "GET /system_management" do
    it "returns 200" do
      get system_management_path
      expect(response).to have_http_status(:ok)
    end

    it "shows reminder frequencies" do
      ReminderFrequency.create!(title: "Six Months")
      get system_management_path
      expect(response.body).to include("Six Months")
    end

    it "shows volunteer tags" do
      VolunteerTag.create!(title: "VIP")
      get system_management_path(tab: "tags")
      expect(response.body).to include("VIP")
    end

    it "shows employees excluding current admin" do
        other = create(:user, first_name: "Joel", last_name: "Savitz", role: :staff)
        get system_management_path(tab: "employees")

        expect(response.body).to include("Joel Savitz")
        expect(response.body).not_to match(/<ul id="employee-list">.*#{admin.full_name}.*<\/ul>/m)
    end

    it "shows referral sources" do
      ReferralSource.create!(name: "Website")
      get system_management_path(tab: "referral_sources")
      expect(response.body).to include("Website")
    end

    it "uses tabs for the lookup sections" do
      get system_management_path
      expect(response.body).to include("Reminder Frequencies")
      expect(response.body).to include("Volunteer Tags")
      expect(response.body).to include("Employees")
      expect(response.body).to include("Referral Sources")
    end

    it "shows recent sync notifications" do
      volunteer = create(:volunteer)
      ExternalSyncLog.create!(
        volunteer: volunteer,
        status: :completed,
        sync_type: :push,
        sync_direction: :outbound,
        started_at: 1.hour.ago,
        completed_at: 1.hour.ago,
        records_processed: 1
      )
      get system_management_path
      expect(response.body).to include(volunteer.full_name)
    end

    it "does not show syncs older than 24 hours" do
      volunteer = create(:volunteer)
      ExternalSyncLog.create!(
        volunteer: volunteer,
        status: :completed,
        sync_type: :push,
        sync_direction: :outbound,
        started_at: 25.hours.ago,
        completed_at: 25.hours.ago,
        records_processed: 1
      )
      get system_management_path
      expect(response.body).not_to include(volunteer.full_name)
    end
  end

  describe "POST /system_management/import" do
    context "with a valid xlsx file" do
      it "imports volunteers and redirects with notice" do
        file = fixture_file_upload("volunteers.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
        expect {
          post import_system_management_path, params: { file: file }
        }.to change(Volunteer, :count).by(1)

        expect(response).to redirect_to(system_management_path)
        follow_redirect!
        expect(response.body).to include("Import complete")
      end
    end

    context "with no file" do
      it "redirects with alert" do
        post import_system_management_path, params: { file: nil }
        expect(response).to redirect_to(system_management_path)
        follow_redirect!
        expect(response.body).to include("No file selected")
      end
    end
  end

  describe "POST /system_management/export_data" do
    it "exports volunteer data to Excel filtered by status and date range" do
      volunteer

      post export_data_system_management_path, params: {
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

      post export_data_system_management_path, params: {
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

RSpec.describe "System management item updates", type: :request do
  let(:admin) { create(:user, role: :admin) }

  before { login_as(admin, scope: :user) }

  it "updates a reminder frequency" do
    freq = ReminderFrequency.create!(title: "Six Months")
    patch reminder_frequency_path(freq), params: { title: "Nine Months" }
    expect(freq.reload.title).to eq("Nine Months")
    expect(response).to redirect_to(system_management_path(tab: "frequencies"))
  end

  it "updates a volunteer tag" do
    tag = VolunteerTag.create!(title: "VIP")
    patch volunteer_tag_path(tag), params: { title: "Evening" }
    expect(tag.reload.title).to eq("Evening")
    expect(response).to redirect_to(system_management_path(tab: "tags"))
  end

  it "updates an employee" do
    other = create(:user, first_name: "Joel", last_name: "Savitz", role: :staff)
    patch user_path(other), params: {
      first_name: "Joseph",
      last_name: "Savitz",
      email: other.email,
      role: "staff"
    }
    expect(other.reload.first_name).to eq("Joseph")
    expect(response).to redirect_to(system_management_path(tab: "employees"))
  end

  it "creates, updates, and removes a referral source" do
    expect {
      post referral_sources_path, params: { name: "Radio", active: "1" }
    }.to change(ReferralSource, :count).by(1)

    source = ReferralSource.find_by!(name: "Radio")
    patch referral_source_path(source), params: { name: "Radio Ad", active: "0" }
    expect(source.reload).to have_attributes(name: "Radio Ad", active: false)

    expect {
      delete referral_source_path(source)
    }.to change(ReferralSource, :count).by(-1)
  end
end
