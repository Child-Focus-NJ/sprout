# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Information session sign-in", type: :request do
  let(:user) { create(:user) }
  let(:information_session) { create(:information_session) }
  let(:volunteer) { create(:volunteer, current_funnel_stage: :inquiry) }

  before { login_as(user, scope: :user) }

  around do |example|
    ActionMailer::Base.deliveries.clear
    example.run
    ActionMailer::Base.deliveries.clear
  end

  describe "GET /information_sessions/:id/sign_in" do
    it "shows the electronic sign-in sheet for the session" do
      get sign_in_information_session_path(information_session)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(information_session.name)
    end
  end

  describe "POST /information_sessions/:id/check_in" do
    it "records attendance for a pre-registered volunteer and queues the application email" do
      SessionRegistration.create!(
        volunteer: volunteer,
        information_session: information_session,
        status: :registered
      )

      expect do
        post check_in_information_session_path(information_session), params: { volunteer_id: volunteer.id }
      end.to change { ActionMailer::Base.deliveries.size }.by(1)

      expect(response).to redirect_to(volunteer_path(volunteer))
      volunteer.reload
      expect(volunteer.application_eligible?).to be true
      expect(volunteer.first_session_attended_at).to be_present

      registration = SessionRegistration.find_by!(volunteer: volunteer, information_session: information_session)
      expect(registration).to be_attended
      expect(registration.checked_in_at).to be_present
    end

    it "records walk-in check-in by email when the volunteer is registered for the session" do
      SessionRegistration.create!(
        volunteer: volunteer,
        information_session: information_session,
        status: :registered
      )

      expect do
        post check_in_information_session_path(information_session), params: { email: volunteer.email }
      end.to change { ActionMailer::Base.deliveries.size }.by(1)

      expect(response).to redirect_to(volunteer_path(volunteer))
      volunteer.reload
      expect(volunteer.application_eligible?).to be true
      registration = SessionRegistration.find_by!(volunteer: volunteer, information_session: information_session)
      expect(registration.checked_in_at).to be_present
    end

    it "redirects walk-in email when already attended without sending another application email" do
      SessionRegistration.create!(
        volunteer: volunteer,
        information_session: information_session,
        status: :attended,
        checked_in_at: 1.hour.ago
      )

      expect do
        post check_in_information_session_path(information_session), params: { email: volunteer.email }
      end.not_to change { ActionMailer::Base.deliveries.size }

      expect(response).to redirect_to(volunteer_path(volunteer))
    end

    it "sends a walk-in without a session registration to the inquiry form with session context" do
      post check_in_information_session_path(information_session), params: { email: "notyet@childfocusnj.org" }

      expect(response).to redirect_to(
        new_inquiry_form_path(information_session_id: information_session.id, email: "notyet@childfocusnj.org")
      )
    end
  end
end
