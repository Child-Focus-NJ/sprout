# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Volunteer SMS send", type: :request do
  let(:user) { create(:user) }
  let(:volunteer) { create(:volunteer, phone: "5559876543") }

  before { login_as(user, scope: :user) }

  describe "POST /volunteers/:id/send_sms" do
    it "records SMS and redirects with notice when message is present" do
      expect do
        post send_sms_volunteer_path(volunteer), params: { message: "Reminder: session tomorrow" }
      end.to change { volunteer.communications.sms.count }.by(1)

      expect(response).to redirect_to(volunteer_path(volunteer))
      follow_redirect!
      expect(response.body).to include("SMS sent")
    end

    it "redirects to compose with alert when message is blank" do
      post send_sms_volunteer_path(volunteer), params: { message: "  " }

      expect(response).to redirect_to(sms_volunteer_path(volunteer))
      expect(flash[:alert]).to match(/blank/i)
    end

    it "redirects to compose with alert when phone is missing" do
      volunteer.update!(phone: nil)

      post send_sms_volunteer_path(volunteer), params: { message: "Hello" }

      expect(response).to redirect_to(sms_volunteer_path(volunteer))
      expect(flash[:alert]).to match(/phone/i)
    end

    it "redirects to compose with alert when message is too long" do
      post send_sms_volunteer_path(volunteer), params: { message: ("x" * 321) }

      expect(response).to redirect_to(sms_volunteer_path(volunteer))
      expect(flash[:alert]).to match(/too long/i)
    end
  end
end
