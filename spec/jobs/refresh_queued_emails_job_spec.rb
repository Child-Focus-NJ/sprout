# frozen_string_literal: true

require "rails_helper"

RSpec.describe RefreshQueuedEmailsJob do
  include_context "Mailchimp email provider"

  let(:volunteer) { create(:volunteer, current_funnel_stage: :application_eligible) }
  let(:user) { create(:user) }
  let(:email_status) { "scheduled" }
  let(:sent_at) { 2.minutes.ago.change(usec: 0) }
  let(:provider_state) { "sent" }
  let!(:communication) { Email::VolunteerNotifications.application!(volunteer: volunteer, sent_by_user: user) }

  before do
    allow(email_client).to receive(:email_info).with(id: communication.external_id, to: volunteer.email)
      .and_return({ "status" => provider_state, "sent_at" => sent_at })
  end

  it "advances a scheduled application only after confirming the original send, exactly once" do
    expect(volunteer.reload).to be_application_eligible
    expect(communication).to be_queued

    2.times { described_class.perform_now }

    expect(communication.reload).to have_attributes(status: "sent", sent_at: sent_at)
    expect(volunteer.reload).to have_attributes(current_funnel_stage: "application_sent", application_sent_at: sent_at)
    expect(volunteer.notes.where(note_type: :communication).count).to eq(1)
    expect(volunteer.status_changes.count).to eq(1)
    expect(email_client).to have_received(:send_email).once
    expect(email_client).to have_received(:email_info).once
  end

  %w[queued scheduled].each do |state|
    context "when still #{state}" do
      let(:provider_state) { state }

      it "keeps the volunteer eligible and prevents another send" do
        described_class.perform_now
        expect(communication.reload).to have_attributes(status: "queued", sent_at: nil)
        expect(volunteer.reload).to have_attributes(current_funnel_stage: "application_eligible", application_sent_at: nil)
        expect { Email::VolunteerNotifications.application!(volunteer: volunteer, sent_by_user: user) }
          .to raise_error(Email::MailchimpOutbound::DuplicateApplicationError)
        expect(email_client).to have_received(:send_email).once
      end
    end
  end

  { "rejected" => "failed", "canceled" => "failed", "bounced" => "bounced" }.each do |state, status|
    context "when #{state}" do
      let(:provider_state) { state }

      it "records the outcome without advancing the volunteer or logging a sent note" do
        described_class.perform_now
        expect(communication.reload).to have_attributes(status: status, sent_at: nil)
        expect(volunteer.reload).to have_attributes(current_funnel_stage: "application_eligible", application_sent_at: nil)
        expect(volunteer.notes).to be_empty
      end
    end
  end

  %w[applied inactive].each do |stage|
    it "does not regress a volunteer who became #{stage} while waiting" do
      volunteer.update!(current_funnel_stage: stage)
      described_class.perform_now
      expect(volunteer.reload).to have_attributes(current_funnel_stage: stage, application_sent_at: sent_at)
    end
  end

  it "preserves failed lookups and continues checking other messages" do
    second = communication.dup
    second.update!(purpose: "inquiry", external_id: "second-id")
    allow(email_client).to receive(:email_info).with(id: second.external_id, to: volunteer.email)
      .and_return({ "status" => "sent", "sent_at" => sent_at })
    allow(email_client).to receive(:email_info).with(id: communication.external_id, to: volunteer.email)
      .and_raise(Mailchimp::TransactionalClient::ApiError)
    described_class.perform_now
    expect(communication.reload).to have_attributes(status: "queued", sent_at: nil)
    expect(second.reload).to be_sent
    expect(volunteer.reload).to be_application_eligible
    expect(email_client).to have_received(:send_email).once
  end

  it "does not query the provider when email is disabled" do
    ENV["SPROUT_EMAIL_MAILCHIMP_ENABLED"] = "false"
    described_class.perform_now
    expect(email_client).not_to have_received(:email_info)
  end

  it "ignores uncertain attempts without a provider ID and SMS records" do
    communication.update!(status: :pending, external_id: nil)
    sms = communication.dup
    sms.update!(communication_type: :sms, status: :queued, external_id: "sms-id")
    described_class.perform_now
    expect(email_client).not_to have_received(:email_info)
  end
end
