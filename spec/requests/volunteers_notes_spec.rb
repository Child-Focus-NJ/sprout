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

    it "returns to the filtered list when the popup was opened there" do
      post add_note_volunteer_path(volunteer), params: { note: "Left a voicemail", return_to: "/volunteers?q=notes" }

      expect(response).to redirect_to("/volunteers?q=notes")
      expect(flash[:notice]).to eq("Note saved for #{volunteer.full_name}")
    end

    it "redirects back with the error when the note is blank" do
      expect do
        post add_note_volunteer_path(volunteer), params: { note: "" }
      end.not_to(change { volunteer.reload.notes.count })

      expect(response).to redirect_to(volunteer_path(volunteer))
      expect(flash[:alert]).to match(/blank/i)
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

  describe "note categories" do
    let(:phone_call) { create(:note_category, name: "Phone call") }

    it "saves the chosen category and shows it as the timeline heading" do
      post add_note_volunteer_path(volunteer), params: { note: "Talked for 10 minutes", note_category_id: phone_call.id }

      expect(volunteer.notes.last.note_category).to eq(phone_call)
      follow_redirect!
      expect(response.parsed_body.at_css(".note-entry .entry__meta strong").text).to eq("Phone call")
    end

    it "uses Note when no category is chosen" do
      post add_note_volunteer_path(volunteer), params: { note: "Left voicemail" }

      expect(volunteer.notes.last.note_category).to eq(NoteCategory.default)
    end

    it "offers the categories that update records only on the profile" do
      NoteCategory.create!(key: "no_show", name: "No-show")

      get volunteer_path(volunteer)
      expect(response.parsed_body.css("#dialog-note-category option").map(&:text)).to include("Note", "No-show")

      get volunteers_path
      expect(response.parsed_body.css("#dialog-note-category option").map(&:text)).to eq([ "Note" ])
    end

    it "lists every category in the timeline filter" do
      phone_call

      get volunteer_path(volunteer)

      options = response.parsed_body.css("#filter optgroup[label='Note categories'] option")
      expect(options.map(&:text)).to include("Phone call")
      expect(options.map { |o| o["value"] }).to include(VolunteerTimeline.note_category_filter(phone_call))
    end
  end

  describe "session outcome notes" do
    let(:session) { create(:information_session) }
    let!(:registration) { SessionRegistration.create!(volunteer: volunteer, information_session: session, status: :registered) }
    let(:no_show) { NoteCategory.create!(key: "no_show", name: "No-show") }

    it "updates the registration for the chosen session" do
      post add_note_volunteer_path(volunteer),
           params: { note: "Didn't come", note_category_id: no_show.id, information_session_id: session.id }

      expect(response).to redirect_to(volunteer_path(volunteer))
      expect(registration.reload).to be_no_show
      expect(volunteer.notes.last.note_category).to eq(no_show)
    end

    it "registers a reschedule for the new session in the same step" do
      rescheduled = NoteCategory.create!(key: "rescheduled", name: "Rescheduled")
      later = create(:information_session, scheduled_at: 2.weeks.from_now)

      post add_note_volunteer_path(volunteer), params: {
        note: "Moving to the next one", note_category_id: rescheduled.id,
        information_session_id: session.id, new_information_session_id: later.id
      }

      expect(registration.reload).to be_rescheduled
      expect(volunteer.session_registrations.find_by!(information_session: later)).to be_registered
    end

    it "explains what's missing and saves nothing without a session" do
      expect do
        post add_note_volunteer_path(volunteer), params: { note: "Didn't come", note_category_id: no_show.id }
      end.not_to change(Note, :count)

      expect(flash[:alert]).to eq("Choose the session this note is about")
      expect(registration.reload).to be_registered
    end

    it "explains a blank note without changing the registration" do
      post add_note_volunteer_path(volunteer),
           params: { note: "", note_category_id: no_show.id, information_session_id: session.id }

      expect(flash[:alert]).to match(/blank/i)
      expect(registration.reload).to be_registered
    end

    it "deactivates the volunteer for a Deactivated note" do
      deactivated = NoteCategory.create!(key: "deactivated", name: "Deactivated")

      post add_note_volunteer_path(volunteer), params: { note: "Moved away", note_category_id: deactivated.id }

      expect(volunteer.reload).to be_inactive
    end

    it "won't add a note that updates records to several volunteers at once" do
      other = create(:volunteer, email: "bulk-outcome@childfocusnj.org")

      expect do
        post bulk_add_note_volunteers_path,
             params: { volunteer_ids: [ volunteer.id, other.id ], note: "Didn't come", note_category_id: no_show.id }
      end.not_to change(Note, :count)

      expect(flash[:alert]).to eq("No-show notes update one volunteer's records, so add them from their profile")
    end
  end

  describe "PATCH /volunteers/:id/notes/:note_id" do
    let!(:note) { volunteer.add_staff_note!(content: "Called on Tuesday", user: user) }

    it "lets the author fix the note and shows it was edited" do
      travel_to(Time.zone.parse("2026-10-20 09:30")) do
        patch update_note_volunteer_path(volunteer, note_id: note.id), params: { note: "Called on Wednesday" }
      end

      expect(response).to redirect_to(volunteer_path(volunteer))
      expect(note.reload).to have_attributes(content: "Called on Wednesday", edited_at: Time.zone.parse("2026-10-20 09:30"))
      follow_redirect!
      expect(response.parsed_body.at_css(".note-entry .entry__edited").text.squish).to eq("· Edited 10/20/2026 09:30")
    end

    it "can move a plain note to another plain category" do
      phone_call = create(:note_category, name: "Phone call")

      patch update_note_volunteer_path(volunteer, note_id: note.id),
            params: { note: note.content, note_category_id: phone_call.id }

      expect(note.reload.note_category).to eq(phone_call)
      expect(note).to be_edited
    end

    it "keeps the category of a note that updated a session" do
      session = create(:information_session)
      SessionRegistration.create!(volunteer: volunteer, information_session: session, status: :registered)
      no_show = NoteCategory.create!(key: "no_show", name: "No-show")
      outcome = volunteer.add_note_with_outcome!(content: "Didn't come", user: user, note_category: no_show,
                                                 information_session: session)

      patch update_note_volunteer_path(volunteer, note_id: outcome.id),
            params: { note: "Didn't come, no call", note_category_id: NoteCategory.default.id }

      expect(outcome.reload).to have_attributes(content: "Didn't come, no call", note_category: no_show)
    end

    it "doesn't mark a note edited when nothing changed" do
      patch update_note_volunteer_path(volunteer, note_id: note.id), params: { note: note.content }

      expect(note.reload).not_to be_edited
    end

    it "keeps the note and goes back to the edit form when the note is blank" do
      patch update_note_volunteer_path(volunteer, note_id: note.id), params: { note: "" }

      expect(response).to redirect_to(volunteer_path(volunteer, edit_note_id: note.id))
      expect(note.reload.content).to eq("Called on Tuesday")
    end

    it "doesn't let anyone else edit the note" do
      login_as(create(:user), scope: :user)

      patch update_note_volunteer_path(volunteer, note_id: note.id), params: { note: "Changed" }

      expect(response).to have_http_status(:not_found)
      expect(note.reload.content).to eq("Called on Tuesday")
    end

    it "doesn't edit notes logged automatically" do
      auto = volunteer.add_staff_note!(content: "Reminder email sent", user: user, note_type: :communication)

      patch update_note_volunteer_path(volunteer, note_id: auto.id), params: { note: "Changed" }

      expect(response).to have_http_status(:not_found)
    end

    it "shows an Edit link only on the current user's own notes and opens the form inline" do
      volunteer.add_staff_note!(content: "Someone else's note", user: create(:user))

      get volunteer_path(volunteer)
      expect(response.parsed_body.css(".entry__edit-link").size).to eq(1)

      get volunteer_path(volunteer, edit_note_id: note.id)
      form = response.parsed_body.at_css("#edit-note-#{note.id}")
      expect(form["action"]).to eq(update_note_volunteer_path(volunteer, note_id: note.id))
      expect(form.at_css("textarea").text).to eq("Called on Tuesday")
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
