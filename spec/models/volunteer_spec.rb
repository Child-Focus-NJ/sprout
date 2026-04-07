# frozen_string_literal: true

require "rails_helper"

RSpec.describe Volunteer, type: :model do
  describe "#profile_status_label" do
    it "returns a clear label for applied" do
      v = build(:volunteer, current_funnel_stage: :applied)
      expect(v.profile_status_label).to eq("Application submitted")
    end

    it "returns a clear label for application_sent" do
      v = build(:volunteer, current_funnel_stage: :application_sent)
      expect(v.profile_status_label).to eq("Application sent")
    end

    it "humanizes other funnel stages" do
      v = build(:volunteer, current_funnel_stage: :application_eligible)
      expect(v.profile_status_label).to eq("Application eligible")
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
      # Avoid PK sequence drift when other tests leave rows (e.g. id=1 exists but sequence still returns 1).
      SessionRegistration.delete_all
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
end
