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
