# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Automatic email failures", type: :request do
  include_context "Mailchimp email provider"
  let(:user) { create(:user) }
  let(:volunteer) { create(:volunteer) }
  let(:information_session) { create(:information_session) }

  before { login_as(user, scope: :user) }

  it "preserves an inquiry when its confirmation email fails" do
    allow(email_client).to receive(:send_email).and_raise(Aws::LambdaClient::LambdaError)
    expect do
      post inquiry_form_path, params: { first_name: "Jane", last_name: "Doe", email: "jane@example.org", phone: "2015550123" }
    end.to change(InquiryFormSubmission, :count).by(1)
    expect(response).to redirect_to(new_inquiry_form_path)
    expect(flash[:notice]).to include("inquiry has been submitted")
    expect(flash[:alert]).to include("Email could not be sent")
    expect(Volunteer.find_by!(email: "jane@example.org").communications.last).to be_failed
  end

  [ "missing link", "disabled sending", "provider failure", "uncertain delivery" ].each do |failure|
    it "preserves attendance and eligibility after #{failure}" do
      SessionRegistration.create!(volunteer: volunteer, information_session: information_session, status: :registered)
      case failure
      when "missing link" then SystemSetting.set("application_url", "")
      when "disabled sending" then ENV["SPROUT_EMAIL_MAILCHIMP_ENABLED"] = "false"
      when "provider failure" then allow(email_client).to receive(:send_email).and_raise(Aws::LambdaClient::LambdaError)
      when "uncertain delivery" then allow(email_client).to receive(:send_email).and_raise(Aws::LambdaClient::UncertainDeliveryError)
      end
      post check_in_information_session_path(information_session), params: { volunteer_id: volunteer.id }
      expect(response).to redirect_to(volunteer_path(volunteer))
      expect(flash[:notice]).to eq("Attendance recorded.")
      expect(flash[:alert]).to include("Attendance recorded.")
      expect(volunteer.reload).to have_attributes(current_funnel_stage: "application_eligible", application_sent_at: nil)
      expect(volunteer.session_registrations.last).to be_attended
    end
  end

  it "does not send another application or regress status at a later session" do
    volunteer.update!(current_funnel_stage: :application_sent, application_sent_at: 1.day.ago)
    SessionRegistration.create!(volunteer: volunteer, information_session: information_session, status: :registered)
    post check_in_information_session_path(information_session), params: { volunteer_id: volunteer.id }
    expect(volunteer.reload).to be_application_sent
    expect(volunteer.session_registrations.last).to be_attended
    expect(email_client).not_to have_received(:send_email)
  end
end
