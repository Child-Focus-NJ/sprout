# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Delete confirmations", type: :request do
  let(:admin) { create(:user, role: :admin) }

  before { login_as(admin, scope: :user) }

  describe "volunteer profile delete" do
    it "shows an in-page confirmation step before deleting" do
      volunteer = create(:volunteer, first_name: "William", last_name: "P")

      get volunteer_path(volunteer, confirm_delete: 1)

      expect(response).to be_successful
      expect(response.body).to include("Delete <strong>William P</strong>?")
      expect(response.body).to include("Yes, delete")
      expect(response.body).to include("Cancel")
    end

    it "deletes the volunteer and redirects to the list" do
      volunteer = create(:volunteer, first_name: "William", last_name: "P")

      expect {
        delete volunteer_path(volunteer)
      }.to change(Volunteer, :count).by(-1)

      expect(response).to redirect_to(volunteers_path)
      follow_redirect!
      expect(response.body).to include("William P was deleted.")
    end
  end

  describe "system management removals" do
    it "shows an in-page confirmation step before removing a reminder frequency" do
      freq = ReminderFrequency.create!(title: "Six Months")

      get system_management_path(tab: "frequencies", confirm_remove_frequency_id: freq.id)

      expect(response).to be_successful
      expect(response.body).to include("Are you sure you want to remove this frequency?")
      expect(response.body).to include("Yes, remove")
    end

    it "shows an in-page confirmation step before removing a volunteer tag" do
      tag = VolunteerTag.create!(title: "VIP")

      get system_management_path(tab: "tags", confirm_remove_tag_id: tag.id)

      expect(response).to be_successful
      expect(response.body).to include("Are you sure you want to remove this tag?")
      expect(response.body).to include("Yes, remove")
    end

    it "shows an in-page confirmation step before removing a referral source" do
      source = ReferralSource.find_or_create_by!(name: "Community Fair") { |rs| rs.active = true }

      get system_management_path(tab: "referral_sources", confirm_remove_referral_source_id: source.id)

      expect(response).to be_successful
      expect(response.body).to include("Are you sure you want to remove this referral source?")
      expect(response.body).to include("Yes, remove")
    end

    it "shows an in-page confirmation step before removing an employee" do
      other = create(:user, first_name: "Joel", last_name: "Savitz", role: :staff)

      get system_management_path(tab: "employees", confirm_remove_user_id: other.id)

      expect(response).to be_successful
      expect(response.body).to include("Are you sure you want to remove this user?")
      expect(response.body).to include("Yes, remove")
    end
  end

  describe "information session deletes" do
    it "shows an in-page confirmation step before deleting a session" do
      session = create(:information_session, name: "Evening Info Session")

      get information_sessions_path(confirm_delete_session_id: session.id)

      expect(response).to be_successful
      expect(response.body).to include('Delete "Evening Info Session"? This cannot be undone.')
      expect(response.body).to include("Yes, delete")
    end

    it "shows an in-page confirmation step before removing an attendee" do
      session = create(:information_session, name: "Evening Info Session")
      volunteer = create(:volunteer, first_name: "John", last_name: "Doe")
      SessionRegistration.create!(information_session: session, volunteer: volunteer)

      get edit_information_session_path(session, confirm_remove_volunteer_id: volunteer.id)

      expect(response).to be_successful
      expect(response.body).to include("Remove John Doe?")
      expect(response.body).to include("Yes, remove")
    end
  end
end
