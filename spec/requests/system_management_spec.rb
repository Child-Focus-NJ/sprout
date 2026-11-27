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
        other = create(:user, first_name: "Joel", last_name: "Savitz", role: :user)
        get system_management_path(tab: "employees")

        expect(response.body).to include("Joel Savitz")
        expect(response.body).not_to match(/<ul id="employee-list">.*#{admin.full_name}.*<\/ul>/m)
    end

    it "shows inquiry sources" do
      ReferralSource.create!(name: "Website")
      get system_management_path(tab: "referral_sources")
      expect(response.body).to include("Website")
    end

    it "uses tabs for the lookup sections" do
      get system_management_path
      expect(response.body).to include("Reminder Frequencies")
      expect(response.body).to include("Volunteer Tags")
      expect(response.body).to include("Employees")
      expect(response.body).to include("Inquiry Sources")
      expect(response.body).to include("Note Categories")
    end

    it "shows note categories, with Remove only on the ones admins added" do
      NoteCategory.create!(key: "no_show", name: "No-show")
      create(:note_category, name: "Phone call")

      get system_management_path(tab: "note_categories")

      rows = response.parsed_body.css("#note-category-list li").to_h do |row|
        [ row.at_css(".volunteer-name").text, row.css("a").map(&:text) ]
      end
      expect(rows).to eq("No-show" => [ "Edit" ], "Phone call" => [ "Edit", "Remove" ])
    end

    it "links to the usage report" do
      get system_management_path
      expect(response.body).to include("View Usage Report")
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
        "Start Date" => "2024-01-01",
        "End Date" => "2026-12-31",
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
        "Start Date" => "2024-01-01",
        "End Date" => "2026-12-31",
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

    it "redirects with an alert when Start Date is after End Date" do
      post export_data_system_management_path, params: {
        "Title" => "backwards-range",
        "export format" => "Excel",
        "Start Date" => "2026-12-31",
        "End Date" => "2024-01-01",
        commit: "Export Data"
      }

      expect(response).to redirect_to(system_management_path)
      follow_redirect!
      expect(response.body).to include("Start Date cannot be after End Date")
      expect(Rails.root.join("tmp", "test_downloads", "backwards-range.xlsx")).not_to exist
    end
  end

  describe "as a non-admin user" do
    before { login_as(create(:user), scope: :user) }

    it "cannot view the Admin tab" do
      get system_management_path

      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include("not authorized")
    end

    it "cannot export volunteer data" do
      volunteer

      post export_data_system_management_path, params: {
        "Title" => "Attendees2024",
        "export format" => "Excel",
        commit: "Export Data"
      }

      expect(response).to redirect_to(root_path)
      expect(Rails.root.join("tmp", "test_downloads", "Attendees2024.xlsx")).not_to exist
    end

    it "cannot import volunteer data" do
      file = fixture_file_upload("volunteers.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")

      expect {
        post import_system_management_path, params: { file: file }
      }.not_to change(Volunteer, :count)

      expect(response).to redirect_to(root_path)
    end

    it "cannot manage employees, even to grant themselves admin" do
      me = create(:user)
      login_as(me, scope: :user)

      patch user_path(me), params: { first_name: me.first_name, last_name: me.last_name, email: me.email, role: "admin" }

      expect(response).to redirect_to(root_path)
      expect(me.reload).not_to be_admin
    end

    it "cannot manage note categories" do
      category = create(:note_category, name: "Phone call")

      expect { post note_categories_path, params: { name: "New" } }.not_to change(NoteCategory, :count)
      expect { patch note_category_path(category), params: { name: "Changed" } }.not_to change { category.reload.name }
      expect { delete note_category_path(category) }.not_to change(NoteCategory, :count)
      expect(response).to redirect_to(root_path)
    end

    it "cannot manage reminder frequencies, volunteer tags, or referral sources" do
      freq = ReminderFrequency.create!(title: "Six Months")
      tag = VolunteerTag.create!(title: "VIP")
      source = ReferralSource.create!(name: "Website")

      expect { post reminder_frequencies_path, params: { title: "New" } }.not_to change(ReminderFrequency, :count)
      expect { post volunteer_tags_path, params: { title: "New" } }.not_to change(VolunteerTag, :count)
      expect { post referral_sources_path, params: { name: "New" } }.not_to change(ReferralSource, :count)

      expect { patch reminder_frequency_path(freq), params: { title: "Changed" } }.not_to change { freq.reload.title }
      expect { patch volunteer_tag_path(tag), params: { title: "Changed" } }.not_to change { tag.reload.title }
      expect { patch referral_source_path(source), params: { name: "Changed" } }.not_to change { source.reload.name }

      expect(response).to redirect_to(root_path)
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
    other = create(:user, first_name: "Joel", last_name: "Savitz", role: :user)
    patch user_path(other), params: {
      first_name: "Joseph",
      last_name: "Savitz",
      email: other.email,
      role: "user"
    }
    expect(other.reload.first_name).to eq("Joseph")
    expect(response).to redirect_to(system_management_path(tab: "employees"))
  end

  it "deactivates an employee instead of deleting them, preserving their record" do
    other = create(:user, first_name: "Joel", last_name: "Savitz", role: :user)

    expect {
      patch user_path(other), params: {
        first_name: other.first_name, last_name: other.last_name, email: other.email, role: other.role, active: "0"
      }
    }.not_to change(User, :count)

    expect(other.reload).not_to be_active
    expect(response).to redirect_to(system_management_path(tab: "employees"))
  end

  it "reactivates a deactivated employee" do
    other = create(:user, :inactive, first_name: "Joel", last_name: "Savitz", role: :user)

    patch user_path(other), params: {
      first_name: other.first_name, last_name: other.last_name, email: other.email, role: other.role, active: "1"
    }

    expect(other.reload).to be_active
  end

  it "refuses to deactivate the last admin" do
    expect {
      patch user_path(admin), params: {
        first_name: admin.first_name, last_name: admin.last_name, email: admin.email, role: admin.role, active: "0"
      }
    }.not_to change { admin.reload.active }

    expect(response).to redirect_to(system_management_path(tab: "employees", edit_user_id: admin.id))
  end

  it "refuses to demote the last admin to user" do
    expect {
      patch user_path(admin), params: {
        first_name: admin.first_name, last_name: admin.last_name, email: admin.email, role: "user"
      }
    }.not_to change { admin.reload.role }
  end

  it "no longer exposes a way to delete an employee outright" do
    other = create(:user, role: :user)

    expect {
      delete "/users/#{other.id}"
    }.not_to change(User, :count)

    expect(response).to have_http_status(:not_found)
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

  it "creates, renames, and removes a note category" do
    expect {
      post note_categories_path, params: { name: "Phone call" }
    }.to change(NoteCategory, :count).by(1)

    category = NoteCategory.find_by!(name: "Phone call")
    patch note_category_path(category), params: { name: "Phone check-in" }
    expect(category.reload.name).to eq("Phone check-in")
    expect(response).to redirect_to(system_management_path(tab: "note_categories"))

    expect {
      delete note_category_path(category)
    }.to change(NoteCategory, :count).by(-1)
  end

  it "renames a built-in note category but won't remove it" do
    no_show = NoteCategory.create!(key: "no_show", name: "No-show")

    patch note_category_path(no_show), params: { name: "Missed session" }
    expect(no_show.reload).to have_attributes(name: "Missed session", key: "no_show")

    expect { delete note_category_path(no_show) }.not_to change(NoteCategory, :count)
    expect(flash[:alert]).to eq("Missed session is built in and can't be removed")
  end

  it "explains a duplicate or blank note category name" do
    create(:note_category, name: "Phone call")

    expect { post note_categories_path, params: { name: "Phone call" } }.not_to change(NoteCategory, :count)
    expect(flash[:alert]).to eq("Name has already been taken")

    category = create(:note_category, name: "Email")
    patch note_category_path(category), params: { name: "" }
    expect(response).to redirect_to(system_management_path(tab: "note_categories", edit_note_category_id: category.id))
    expect(category.reload.name).to eq("Email")
  end

  describe "Possible Duplicates" do
    let!(:maria) { create(:volunteer, first_name: "Maria", last_name: "Lopez", phone: "(973) 555-0182") }
    let!(:other_maria) { create(:volunteer, first_name: "maria", last_name: "Lopez", phone: "973-555-0182") }

    def pairs
      response.parsed_body.css("#possible-duplicates .duplicate-pair")
    end

    it "lists each pair with profile links, why they matched, and Merge and Not a duplicate buttons" do
      create(:volunteer, first_name: "Sam", last_name: "Reed", phone: "201-555-0148")

      get system_management_path(tab: "duplicates")

      expect(pairs.size).to eq(1)
      expect(pairs.first.css(".duplicate-pair__name").map { |link| link["href"] }).to eq([ volunteer_path(maria), volunteer_path(other_maria) ])
      expect(pairs.first.css(".duplicate-pair__reason").map(&:text)).to eq([ "Same name", "Same phone" ])
      expect(pairs.first.css(".duplicate-pair__actions button").map(&:text)).to eq([ "Merge", "Not a duplicate" ])
      expect(pairs.first.at_css(".duplicate-pair__dismiss")["action"]).to eq(duplicate_dismissals_path)
    end

    it "offers a Merge popup to choose the name, email, phone and status to keep" do
      other_maria.update!(email: "mlopez@work.org", current_funnel_stage: :application_eligible)

      get system_management_path(tab: "duplicates")

      dialog = pairs.first.at_css("dialog.merge-dialog")
      expect(pairs.first.at_css("[data-merge-dialog-open]")["data-merge-dialog-open"]).to eq(dialog["id"])
      expect(dialog.at_css("form")["action"]).to eq(duplicate_merges_path)
      options = ->(field) { dialog.css("input[name='keep[#{field}]'][type=radio]").map { |radio| [ radio.parent.text.squish, radio["checked"].present? ] } }
      expect(options.call("name")).to eq([ [ "Maria Lopez", true ], [ "maria Lopez", false ] ])
      expect(options.call("email")).to eq([ [ maria.email, false ], [ "mlopez@work.org", true ] ])
      expect(options.call("phone")).to eq([ [ "(973) 555-0182", false ], [ "973-555-0182", true ] ])
      expect(options.call("status")).to eq([ [ "Inquiry", false ], [ "Application eligible", true ] ])
    end

    it "shows a single value instead of a choice when both records have the same one" do
      get system_management_path(tab: "duplicates")

      status = pairs.first.css(".merge-dialog__field").find { |field| field.at_css("legend").text == "Status" }
      expect(status.at_css(".merge-dialog__only").text.squish).to eq("Inquiry · Same on both")
      expect(status.at_css("input[type=hidden][name='keep[status]']")["value"]).to eq(maria.id.to_s)
    end

    it "merges a pair into one profile with what staff chose" do
      post duplicate_merges_path, params: {
        volunteer_id: maria.id, other_volunteer_id: other_maria.id,
        keep: { name: maria.id, email: other_maria.id, phone: maria.id, status: maria.id }
      }

      expect(response).to redirect_to(system_management_path(tab: "duplicates"))
      expect(flash[:notice]).to eq("Merged the two records into Maria Lopez's profile.")
      expect(Volunteer.sole).to have_attributes(id: maria.id, email: other_maria.email, phone: "(973) 555-0182")
      get system_management_path(tab: "duplicates")
      expect(pairs).to be_empty
    end

    it "handles a second click or an unknown volunteer without an error" do
      2.times { post duplicate_merges_path, params: { volunteer_id: maria.id, other_volunteer_id: other_maria.id } }

      expect(response).to redirect_to(system_management_path(tab: "duplicates"))
      expect(flash[:alert]).to eq("Couldn't find both volunteers.")
      expect(Volunteer.sole).to eq(maria)
    end

    it "only lets admins merge" do
      login_as(create(:user, role: :user), scope: :user)

      post duplicate_merges_path, params: { volunteer_id: maria.id, other_volunteer_id: other_maria.id }

      expect(response).to redirect_to(root_path)
      expect(Volunteer.count).to eq(2)
    end

    it "shows a red count on the tab and a red dot on the Admin link while there are pairs" do
      get system_management_path

      expect(response.parsed_body.at_css(".sys-tabs a[href='#{system_management_path(tab: 'duplicates')}']").text.squish)
        .to eq("Possible Duplicates 1")
      expect(response.parsed_body.at_css(".app-navbar__links .app-navbar__dot")).to be_present
    end

    it "explains when there's nothing to check and shows no dot" do
      other_maria.destroy!

      get system_management_path(tab: "duplicates")

      expect(response.body).to include("No possible duplicates right now.")
      expect(response.parsed_body.at_css(".sys-tabs__alert-count")).to be_nil
      expect(response.parsed_body.at_css(".app-navbar__dot")).to be_nil
    end

    it "stops showing a pair once it's marked not a duplicate" do
      post duplicate_dismissals_path, params: { volunteer_id: other_maria.id, other_volunteer_id: maria.id }

      expect(response).to redirect_to(system_management_path(tab: "duplicates"))
      expect(flash[:notice]).to eq("Maria Lopez and maria Lopez won't show as possible duplicates again.")
      expect(DuplicateDismissal.sole).to have_attributes(volunteer: maria, other_volunteer: other_maria, user: admin)
      get system_management_path(tab: "duplicates")
      expect(pairs).to be_empty
    end

    it "handles a second click or an unknown volunteer without an error" do
      2.times do
        post duplicate_dismissals_path, params: { volunteer_id: maria.id, other_volunteer_id: other_maria.id }
        expect(response).to redirect_to(system_management_path(tab: "duplicates"))
      end
      post duplicate_dismissals_path, params: { volunteer_id: maria.id, other_volunteer_id: 0 }

      expect(response).to redirect_to(system_management_path(tab: "duplicates"))
      expect(flash[:alert]).to eq("Couldn't find both volunteers.")
      expect(DuplicateDismissal.count).to eq(1)
    end

    it "is admin only" do
      login_as(create(:user, role: :user), scope: :user)

      post duplicate_dismissals_path, params: { volunteer_id: maria.id, other_volunteer_id: other_maria.id }

      expect(response).to redirect_to(root_path)
      expect(DuplicateDismissal.count).to eq(0)
    end
  end
end
