# frozen_string_literal: true

require "rails_helper"

RSpec.describe Volunteer, type: :model do
  describe "#add_staff_note!" do
    it "creates a note with the given user and type" do
      user = create(:user)
      volunteer = create(:volunteer)

      expect do
        volunteer.add_staff_note!(content: "Left voicemail", user: user, note_type: :general)
      end.to change { volunteer.notes.count }.by(1)

      n = volunteer.notes.last
      expect(n.content).to eq("Left voicemail")
      expect(n.user).to eq(user)
      expect(n.general?).to be true
    end

    it "raises when content is blank (model validation)" do
      user = create(:user)
      volunteer = create(:volunteer)

      expect do
        volunteer.add_staff_note!(content: "", user: user)
      end.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe "#status" do
    it "returns attended_session when first-session attendance is recorded" do
      v = build(:volunteer, first_session_attended_at: 1.day.ago, current_funnel_stage: :inquiry)
      expect(v.status).to eq(:attended_session)
    end

    it "reflects funnel stage when the volunteer has not yet attended a session" do
      v = build(:volunteer, first_session_attended_at: nil, current_funnel_stage: :application_eligible)
      expect(v.status).to eq(:application_eligible)
    end
  end

  describe "#change_status!" do
    it "updates the funnel stage and records a status change" do
      user = create(:user)
      volunteer = create(:volunteer, current_funnel_stage: :inquiry)

      expect do
        volunteer.change_status!(:application_eligible, user: user, trigger: :manual)
      end.to change { volunteer.status_changes.count }.by(1)

      volunteer.reload
      expect(volunteer.application_eligible?).to be true
      last = volunteer.status_changes.last
      expect(last.from_funnel_stage).to eq("Inquiry")
      expect(last.to_funnel_stage).to eq("Application eligible")
      expect(last.user).to eq(user)
      expect(last.manual?).to be true
    end

    it "does nothing when the stage is unchanged" do
      volunteer = create(:volunteer, current_funnel_stage: :inquiry)
      expect do
        volunteer.change_status!(:inquiry, user: nil, trigger: :manual)
      end.not_to change { volunteer.status_changes.count }
    end
  end

  describe ".awaiting_application_submission" do
    it "orders application_sent volunteers by application_sent_at ascending" do
      older = create(:volunteer, current_funnel_stage: :application_sent, application_sent_at: 2.days.ago)
      newer = create(:volunteer, current_funnel_stage: :application_sent, application_sent_at: 1.day.ago)
      create(:volunteer, current_funnel_stage: :inquiry)

      expect(described_class.awaiting_application_submission.pluck(:id)).to eq([ older.id, newer.id ])
    end
  end

  describe ".name_matching" do
    let!(:harry) { create(:volunteer, first_name: "Harry", last_name: "Kane") }
    let!(:hana) { create(:volunteer, first_name: "Hana", last_name: "Kimura") }
    let!(:sofia) { create(:volunteer, first_name: "Sofia", last_name: "Reyes") }

    it "matches first or last name, ignoring case" do
      expect(described_class.name_matching("KANE")).to contain_exactly(harry)
      expect(described_class.name_matching("sofia")).to contain_exactly(sofia)
    end

    it "matches partial names" do
      expect(described_class.name_matching("ha")).to contain_exactly(harry, hana)
    end

    it "requires every word to match, so a full name narrows the results" do
      expect(described_class.name_matching("harry kane")).to contain_exactly(harry)
      expect(described_class.name_matching("harry reyes")).to be_empty
    end

    it "returns everyone for a blank query" do
      expect(described_class.name_matching("  ")).to contain_exactly(harry, hana, sofia)
    end

    it "treats SQL wildcards as literal characters" do
      expect(described_class.name_matching("%")).to be_empty
      expect(described_class.name_matching("_")).to be_empty
    end
  end

  describe "#record_application_sent!" do
    it "sets stage, sent time, and returns true" do
      user = create(:user)
      volunteer = create(:volunteer, current_funnel_stage: :application_eligible, application_sent_at: nil)

      expect(volunteer.record_application_sent!(user: user)).to be true
      volunteer.reload
      expect(volunteer.application_sent?).to be true
      expect(volunteer.application_sent_at).to be_present
    end

    it "returns false when application was already sent" do
      user = create(:user)
      volunteer = create(:volunteer, current_funnel_stage: :application_sent, application_sent_at: 1.day.ago)

      expect(volunteer.record_application_sent!(user: user)).to be false
    end
  end

  describe "#mark_application_submitted!" do
    it "records submission time and moves to applied" do
      user = create(:user)
      volunteer = create(:volunteer, current_funnel_stage: :application_sent, application_sent_at: 1.day.ago)

      volunteer.mark_application_submitted!(user: user)
      volunteer.reload
      expect(volunteer.applied?).to be true
      expect(volunteer.application_submitted_at).to be_present
    end
  end

  describe "pending reminder cancellation when applied" do
    it "cancels pending scheduled reminders when status becomes applied" do
      template = CommunicationTemplate.create!(
        name: "Application nudge",
        body: "Please submit your application.",
        funnel_stage: :application_sent
      )
      volunteer = create(:volunteer, current_funnel_stage: :application_sent, application_sent_at: 1.day.ago)
      reminder = volunteer.scheduled_reminders.create!(
        communication_template: template,
        scheduled_for: 1.day.from_now,
        status: :pending
      )

      volunteer.change_status!(:applied, user: nil, trigger: :manual)

      expect(reminder.reload.cancelled?).to be true
    end
  end

  describe "#finalize_check_in_for_session!" do
    before do
      SessionRegistration.delete_all
      InquiryFormSubmission.delete_all
      InformationSession.delete_all
      ActiveRecord::Base.connection.reset_pk_sequence!("information_sessions")
    end

    it "marks attendance, moves to application eligible, and does not set application_sent_at" do
      admin = create(:user)
      session = create(:information_session)
      volunteer = create(:volunteer, current_funnel_stage: :inquiry, application_sent_at: nil)
      SessionRegistration.create!(
        volunteer: volunteer,
        information_session: session,
        status: :registered
      )

      volunteer.finalize_check_in_for_session!(session, user: admin)

      volunteer.reload
      expect(volunteer.application_eligible?).to be true
      expect(volunteer.application_sent_at).to be_nil
      expect(volunteer.first_session_attended_at).to be_present
      expect(volunteer.status_changes.last.event?).to be true
    end
  end

  describe "#add_note_with_outcome!" do
    let(:admin) { create(:user) }
    let(:volunteer) { create(:volunteer, current_funnel_stage: :inquiry) }
    let(:session) { create(:information_session) }
    let!(:registration) { SessionRegistration.create!(volunteer: volunteer, information_session: session, status: :registered) }

    def category(key)
      NoteCategory.find_or_create_by!(key: key) { |c| c.name = key.humanize }
    end

    it "marks a no-show on the chosen session's registration" do
      note = volunteer.add_note_with_outcome!(content: "Didn't come", user: admin,
                                              note_category: category("no_show"), information_session: session)

      expect(note.note_category.key).to eq("no_show")
      expect(registration.reload).to be_no_show
    end

    it "marks a cancellation on the chosen session's registration" do
      volunteer.add_note_with_outcome!(content: "Can't make it", user: admin,
                                       note_category: category("cancelled"), information_session: session)

      expect(registration.reload).to be_cancelled
    end

    it "records attendance and moves an inquiry to application eligible" do
      volunteer.add_note_with_outcome!(content: "Came late", user: admin,
                                       note_category: category("attended_info_session"), information_session: session)

      expect(registration.reload).to be_attended
      expect(registration.checked_in_at).to eq(session.scheduled_at)
      expect(volunteer.reload.first_session_attended_at).to eq(session.scheduled_at)
      expect(volunteer).to be_application_eligible
    end

    it "doesn't move a volunteer who's further along or inactive back to application eligible" do
      %i[application_sent applied inactive].each do |stage|
        volunteer.update!(current_funnel_stage: stage)

        volunteer.add_note_with_outcome!(content: "Came to another session", user: admin,
                                         note_category: category("attended_info_session"), information_session: session)

        expect(volunteer.reload.current_funnel_stage).to eq(stage.to_s)
      end
    end

    it "keeps the check-in time of a session already marked attended" do
      checked_in_at = Time.zone.parse("2026-10-01 18:05")
      registration.update!(status: :attended, checked_in_at: checked_in_at)

      volunteer.add_note_with_outcome!(content: "Stayed for the whole session", user: admin,
                                       note_category: category("attended_info_session"), information_session: session)

      expect(registration.reload.checked_in_at).to eq(checked_in_at)
    end

    it "won't mark an attended session as a no-show, cancelled, or rescheduled" do
      registration.update!(status: :attended, checked_in_at: Time.current)
      later = create(:information_session, scheduled_at: 2.weeks.from_now)

      %w[no_show cancelled rescheduled].each do |key|
        expect do
          expect do
            volunteer.add_note_with_outcome!(content: "Changed my mind", user: admin, note_category: category(key),
                                             information_session: session, new_information_session: later)
          end.to raise_error(Volunteer::OutcomeNoteError, /already attended that session, so it can't be marked/)
        end.not_to change(Note, :count)
      end

      expect(registration.reload).to be_attended
      expect(volunteer.session_registrations.find_by(information_session: later)).to be_nil
    end

    it "moves a reschedule to the new session in the same step" do
      later = create(:information_session, scheduled_at: 2.weeks.from_now)

      volunteer.add_note_with_outcome!(content: "Moving to the next one", user: admin, note_category: category("rescheduled"),
                                       information_session: session, new_information_session: later)

      expect(registration.reload).to be_rescheduled
      expect(volunteer.session_registrations.find_by!(information_session: later)).to be_registered
    end

    it "deactivates the volunteer for a Deactivated note" do
      volunteer.add_note_with_outcome!(content: "No longer interested", user: admin, note_category: category("deactivated"))

      expect(volunteer.reload).to be_inactive
      expect(volunteer.status_changes.last).to have_attributes(to_funnel_stage: "Inactive", user_id: admin.id)
    end

    it "saves nothing when the session is missing" do
      expect do
        expect do
          volunteer.add_note_with_outcome!(content: "Didn't come", user: admin, note_category: category("no_show"))
        end.to raise_error(Volunteer::OutcomeNoteError, "Choose the session this note is about")
      end.not_to change(Note, :count)
    end

    it "refuses a session the volunteer isn't registered for" do
      other_session = create(:information_session)

      expect do
        volunteer.add_note_with_outcome!(content: "Didn't come", user: admin,
                                         note_category: category("no_show"), information_session: other_session)
      end.to raise_error(Volunteer::OutcomeNoteError, /isn't registered for that session/)
    end

    it "rolls back the note and the old registration when a reschedule has no new session" do
      expect do
        expect do
          volunteer.add_note_with_outcome!(content: "Moving", user: admin, note_category: category("rescheduled"),
                                           information_session: session)
        end.to raise_error(Volunteer::OutcomeNoteError, "Choose the session they're rescheduling to")
      end.not_to change(Note, :count)
      expect(registration.reload).to be_registered
    end

    it "doesn't reset the new session to registered when the volunteer already attended it" do
      later = create(:information_session, scheduled_at: 2.weeks.from_now)
      attended = SessionRegistration.create!(volunteer: volunteer, information_session: later, status: :attended)

      volunteer.add_note_with_outcome!(content: "Moving", user: admin, note_category: category("rescheduled"),
                                       information_session: session, new_information_session: later)

      expect(attended.reload).to be_attended
      expect(registration.reload).to be_rescheduled
    end

    it "won't reschedule to a full session" do
      later = create(:information_session, scheduled_at: 2.weeks.from_now, capacity: 1)
      SessionRegistration.create!(volunteer: create(:volunteer), information_session: later, status: :registered)

      expect do
        volunteer.add_note_with_outcome!(content: "Moving", user: admin, note_category: category("rescheduled"),
                                         information_session: session, new_information_session: later)
      end.to raise_error(Volunteer::OutcomeNoteError, "The session they're rescheduling to is full")
      expect(registration.reload).to be_registered
      expect(volunteer.session_registrations.find_by(information_session: later)).to be_nil
    end

    it "refuses to reschedule to the same session" do
      expect do
        volunteer.add_note_with_outcome!(content: "Moving", user: admin, note_category: category("rescheduled"),
                                         information_session: session, new_information_session: session)
      end.to raise_error(Volunteer::OutcomeNoteError, "Choose a different session to reschedule to")
      expect(registration.reload).to be_registered
    end
  end

  describe "associations" do
    it "can be created without a vicinage or referral source" do
      volunteer = build(:volunteer, vicinage: nil, referral_source: nil)
      expect(volunteer).to be_valid
    end

    it "belongs to a vicinage" do
      vicinage = create(:vicinage)
      volunteer = create(:volunteer, vicinage: vicinage)
      expect(volunteer.vicinage).to eq(vicinage)
    end
  end

  describe "#vicinage_name" do
    it "returns the associated vicinage's name" do
      vicinage = create(:vicinage, name: "Passaic")
      volunteer = build(:volunteer, vicinage: vicinage)
      expect(volunteer.vicinage_name).to eq("Passaic")
    end

    it "returns nil when no vicinage is set" do
      volunteer = build(:volunteer, vicinage: nil)
      expect(volunteer.vicinage).to be_nil
    end
  end

  describe "#referral_source_name" do
    it "returns nil when no referral source is set" do
      volunteer = build(:volunteer, referral_source: nil)
      expect(volunteer.referral_source_name).to be_nil
    end
  end

  describe "#stage_started_at and #days_in_current_stage" do
    it "anchors the inquiry stage on inquiry_date" do
      volunteer = create(:volunteer, current_funnel_stage: :inquiry, inquiry_date: 45.days.ago)
      expect(volunteer.stage_started_at).to be_within(1.second).of(45.days.ago)
      expect(volunteer.days_in_current_stage).to eq(45)
    end

    it "falls back to created_at for inquiry when inquiry_date is blank" do
      volunteer = create(:volunteer, current_funnel_stage: :inquiry, inquiry_date: nil)
      expect(volunteer.stage_started_at).to be_within(1.second).of(volunteer.created_at)
    end

    it "anchors the application_eligible stage on first_session_attended_at" do
      volunteer = create(:volunteer, current_funnel_stage: :application_eligible, first_session_attended_at: 60.days.ago)
      expect(volunteer.days_in_current_stage).to eq(60)
    end

    it "anchors the application_sent stage on application_sent_at" do
      volunteer = create(:volunteer, current_funnel_stage: :application_sent, application_sent_at: 90.days.ago)
      expect(volunteer.days_in_current_stage).to eq(90)
    end

    it "returns nil when the stage has no start timestamp yet" do
      volunteer = create(:volunteer, current_funnel_stage: :application_eligible, first_session_attended_at: nil)
      expect(volunteer.days_in_current_stage).to be_nil
    end

    it "returns nil for terminal stages (applied, inactive)" do
      applied = create(:volunteer, current_funnel_stage: :applied)
      inactive = create(:volunteer, current_funnel_stage: :inactive)

      expect(applied.days_in_current_stage).to be_nil
      expect(inactive.days_in_current_stage).to be_nil
    end
  end
end
