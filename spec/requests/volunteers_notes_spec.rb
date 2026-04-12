# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Volunteer notes (US8)", type: :request do
  let(:user) { create(:user) }
  let(:volunteer) { create(:volunteer, email: "notes-flow@childfocusnj.org") }

  before { login_as(user, scope: :user) }

  describe "POST /volunteers/:id/add_note" do
    it "saves a note and redirects to the profile" do
      expect do
        post add_note_volunteer_path(volunteer), params: { note: "Send 4 week follow up email" }
      end.to change { volunteer.reload.notes.count }.by(1)

      expect(response).to redirect_to(volunteer_path(volunteer))
      follow_redirect!
      expect(response.body).to include("Send 4 week follow up email")
      expect(volunteer.notes.last.user).to eq(user)
    end
  end

  describe "POST /volunteers/bulk_add_note" do
    let(:other) { create(:volunteer, email: "bulk-b@childfocusnj.org") }

    it "adds the same note to each selected volunteer" do
      post bulk_add_note_volunteers_path, params: {
        volunteer_ids: [ volunteer.id, other.id ],
        note: "Send 4 week follow up email"
      }

      expect(response).to redirect_to(volunteers_path)
      expect(flash[:notice]).to match(/2 volunteers/)

      expect(volunteer.reload.notes.last.content).to eq("Send 4 week follow up email")
      expect(other.reload.notes.last.content).to eq("Send 4 week follow up email")
    end
  end

  describe "GET /volunteers/:id with timeline filter" do
    before do
      volunteer.add_staff_note!(content: "Profile note", user: user, note_type: :general)
    end

    it "renders the notes-only filter" do
      get volunteer_path(volunteer), params: { filter: "notes" }
      expect(response).to be_successful
      expect(response.body).to include("Profile note")
      expect(response.body).to include('value="notes"')
    end
  end
end
