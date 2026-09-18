# frozen_string_literal: true

require "rails_helper"

RSpec.describe Email::VolunteerNotifications do
  include_context "Mailchimp email provider"
  let(:volunteer) { create(:volunteer, current_funnel_stage: :application_eligible) }
  let(:user) { create(:user) }

  def send_application
    described_class.application!(volunteer: volunteer, sent_by_user: user)
  end

  it "uses the current admin setting and changes status only after a confirmed send" do
    SystemSetting.set("application_url", "https://example.org/new-application")
    communication = send_application
    expect(communication.body).to include("https://example.org/new-application")
    expect(volunteer.reload).to have_attributes(current_funnel_stage: "application_sent", application_sent_at: communication.sent_at)
    expect(communication.purpose).to eq("application")
    expect { send_application }.to raise_error(Email::MailchimpOutbound::DuplicateApplicationError)
    expect(email_client).to have_received(:send_email).once
  end

  it "requires an application link without sending or advancing the volunteer" do
    SystemSetting.set("application_url", "")
    expect { send_application }.to raise_error(Email::MailchimpOutbound::ConfigurationError, /Admin settings/)
    expect(volunteer.reload).to have_attributes(current_funnel_stage: "application_eligible", application_sent_at: nil)
    expect(volunteer.communications).to be_empty
    expect(email_client).not_to have_received(:send_email)
  end

  context "when queued" do
    let(:email_status) { "queued" }

    it "blocks duplicate sends while leaving the sent date unset" do
      expect(send_application).to be_queued
      expect(volunteer.reload).to have_attributes(current_funnel_stage: "application_eligible", application_sent_at: nil)
      expect { send_application }.to raise_error(Email::MailchimpOutbound::DuplicateApplicationError)
      expect(email_client).to have_received(:send_email).once
    end
  end

  it "retains an uncertain attempt and blocks a second application send" do
    allow(email_client).to receive(:send_email).and_raise(Aws::LambdaClient::UncertainDeliveryError)
    expect { send_application }.to raise_error(Email::MailchimpOutbound::Error, /could not be confirmed/)
    expect { send_application }.to raise_error(Email::MailchimpOutbound::DuplicateApplicationError)
    expect(volunteer.reload.application_sent_at).to be_nil
    expect(email_client).to have_received(:send_email).once
  end

  it "allows retrying a definite rejection and uses the updated link" do
    allow(email_client).to receive(:send_email).and_return({ "to" => volunteer.email, "status" => "rejected", "external_id" => "reject-id" })
    expect { send_application }.to raise_error(Email::MailchimpOutbound::Error, /rejected/)
    expect(volunteer.reload.application_sent_at).to be_nil
    SystemSetting.set("application_url", "https://example.org/revised")
    allow(email_client).to receive(:send_email).and_return({ "to" => volunteer.email, "status" => "sent", "external_id" => "retry-id" })
    expect(send_application.body).to include("https://example.org/revised")
    expect(volunteer.communications.email.count).to eq(2)
    expect(volunteer.reload).to be_application_sent
  end

  it "keeps an application in progress from creating another provider call" do
    allow(email_client).to receive(:send_email) do |to:, **|
      expect { send_application }.to raise_error(Email::MailchimpOutbound::DuplicateApplicationError)
      { "to" => to, "status" => "sent", "external_id" => "id" }
    end
    send_application
    expect(email_client).to have_received(:send_email).once
  end

  it "does not regress a volunteer who submits while the provider request is in progress" do
    allow(email_client).to receive(:send_email) do |to:, **|
      volunteer.update!(current_funnel_stage: :applied, application_submitted_at: Time.current)
      { "to" => to, "status" => "sent", "external_id" => "id" }
    end
    send_application
    expect(volunteer.reload).to be_applied
  end

  it "records an automated inquiry confirmation without a staff sender" do
    communication = described_class.inquiry!(volunteer: volunteer)
    expect(communication).to have_attributes(status: "sent", purpose: "inquiry", sent_by_user: nil, subject: "Thanks for your inquiry")
  end
end
