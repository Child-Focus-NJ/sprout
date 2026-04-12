# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Inquiry form walk-in check-in", type: :request do
  let(:user) { create(:user) }
  let(:information_session) { create(:information_session) }

  before { login_as(user, scope: :user) }

  around do |example|
    ActionMailer::Base.deliveries.clear
    example.run
    ActionMailer::Base.deliveries.clear
  end

  describe "POST /inquiry_form with session context" do
    it "creates a volunteer, records attendance, and sends the application-queued email" do
      expect do
        post inquiry_form_path, params: {
          information_session_id: information_session.id,
          first_name: "Pat",
          last_name: "Walker",
          email: "walkin-new@childfocusnj.org",
          phone: "5551234567"
        }
      end.to change(Volunteer, :count).by(1)
        .and change { ActionMailer::Base.deliveries.size }.by(1)

      volunteer = Volunteer.find_by!(email: "walkin-new@childfocusnj.org")
      expect(volunteer.email).to eq("walkin-new@childfocusnj.org")
      expect(response).to redirect_to(volunteer_path(volunteer))

      registration = SessionRegistration.find_by!(volunteer: volunteer, information_session: information_session)
      expect(registration).to be_attended
      expect(registration.checked_in_at).to be_present
      expect(volunteer.first_session_attended_at).to be_present
      expect(volunteer.status).to eq(:attended_session)
    end

    it "checks in an existing volunteer already registered for the session" do
      volunteer = create(:volunteer, email: "existing-walkin@childfocusnj.org", current_funnel_stage: :inquiry)
      SessionRegistration.create!(
        volunteer: volunteer,
        information_session: information_session,
        status: :registered
      )

      expect do
        post inquiry_form_path, params: {
          information_session_id: information_session.id,
          first_name: volunteer.first_name,
          last_name: volunteer.last_name,
          email: volunteer.email,
          phone: "5559876543"
        }
      end.to change { ActionMailer::Base.deliveries.size }.by(1)

      expect(response).to redirect_to(volunteer_path(volunteer))
      volunteer.reload
      expect(volunteer.application_eligible?).to be true
    end

    it "redirects when the volunteer is already marked attended for the session" do
      volunteer = create(:volunteer, email: "already-in@childfocusnj.org")
      SessionRegistration.create!(
        volunteer: volunteer,
        information_session: information_session,
        status: :attended,
        checked_in_at: 1.hour.ago
      )

      expect do
        post inquiry_form_path, params: {
          information_session_id: information_session.id,
          first_name: volunteer.first_name,
          last_name: volunteer.last_name,
          email: volunteer.email,
          phone: "5551112222"
        }
      end.not_to change { ActionMailer::Base.deliveries.size }

      expect(response).to redirect_to(volunteer_path(volunteer))
    end
  end
end
