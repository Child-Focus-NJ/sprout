# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Volunteer status management", type: :request do
  let(:user) { create(:user) }
  let(:volunteer) { create(:volunteer, current_funnel_stage: :inquiry, email: "status-spec@childfocusnj.org") }

  before { login_as(user, scope: :user) }

  describe "PATCH /volunteers/:id/update_status" do
    it "changes status and redirects to the profile" do
      patch update_status_volunteer_path(volunteer), params: { status: "application_eligible" }

      expect(response).to redirect_to(volunteer_path(volunteer))
      follow_redirect!
      expect(response.body).to include("Application eligible")

      volunteer.reload
      expect(volunteer.application_eligible?).to be true
      expect(volunteer.status_changes.last.to_funnel_stage).to eq("Application eligible")
    end
  end

  describe "POST /volunteers/:id/send_application" do
    it "blocks duplicate sends when an application was already sent" do
      volunteer.update!(current_funnel_stage: :application_sent, application_sent_at: 1.day.ago)

      post send_application_volunteer_path(volunteer)

      expect(response).to redirect_to(volunteer_path(volunteer))
      expect(flash[:alert]).to match(/already sent/i)
    end

    it "sends when eligible and records sent time" do
      volunteer.update!(current_funnel_stage: :application_eligible, application_sent_at: nil)

      post send_application_volunteer_path(volunteer)

      expect(response).to redirect_to(volunteer_path(volunteer))
      volunteer.reload
      expect(volunteer.application_sent?).to be true
      expect(volunteer.application_sent_at).to be_present
    end
  end

  describe "PATCH /volunteers/:id/mark_submitted" do
    it "records submission and moves to applied" do
      volunteer.update!(current_funnel_stage: :application_sent, application_sent_at: 1.day.ago)

      patch mark_submitted_volunteer_path(volunteer)

      expect(response).to redirect_to(volunteer_path(volunteer))
      volunteer.reload
      expect(volunteer.applied?).to be true
      expect(volunteer.application_submitted_at).to be_present
    end
  end
end
