# frozen_string_literal: true

require "rails_helper"

RSpec.describe Email::MailchimpOutbound do
  include_context "Mailchimp email provider"
  let(:volunteer) { create(:volunteer) }
  let(:user) { create(:user) }

  def deliver(subject: "Hello", body: "A message")
    described_class.deliver!(volunteer: volunteer, subject: subject, body: body, sent_by_user: user)
  end

  it "records the provider result, recipient and staff sender without claiming delivery" do
    communication = deliver
    expect(communication).to have_attributes(status: "sent", external_id: "spec-email-id", email_to: volunteer.email, sent_by_user: user)
    expect(communication.sent_at).to be_present
    expect(volunteer.notes.count).to eq(1)
    expect(email_client).to have_received(:send_email).with(to: volunteer.email, subject: "Hello", text_body: "A message")
  end

  %w[queued scheduled].each do |status|
    context "when the provider returns #{status}" do
      let(:email_status) { status }

      it "records queued without a sent time or sent note" do
        expect(deliver).to have_attributes(status: "queued", sent_at: nil, external_id: "spec-email-id")
        expect(volunteer.notes).to be_empty
      end
    end
  end

  %w[rejected invalid].each do |status|
    context "when the provider returns #{status}" do
      let(:email_status) { status }

      it "records failure without claiming success" do
        expect { deliver }.to raise_error(described_class::Error, /rejected/)
        expect(volunteer.communications.last).to have_attributes(status: "failed", sent_at: nil, external_id: "spec-email-id")
        expect(volunteer.notes).to be_empty
      end
    end
  end

  it "does not send or record success when sending is disabled" do
    ENV["SPROUT_EMAIL_MAILCHIMP_ENABLED"] = "false"
    expect { deliver }.to raise_error(described_class::ConfigurationError)
    expect(volunteer.communications).to be_empty
    expect(email_client).not_to have_received(:send_email)
  end

  it "validates recipient, subject and body before creating an attempt" do
    expect { deliver(subject: " ") }.to raise_error(described_class::ValidationError)
    expect { deliver(subject: "x" * 999) }.to raise_error(described_class::ValidationError)
    expect { deliver(subject: "Hello\nBcc: another@example.org") }.to raise_error(described_class::ValidationError)
    expect { deliver(body: " ") }.to raise_error(described_class::ValidationError)
    volunteer.update_column(:email, "invalid")
    expect { deliver }.to raise_error(described_class::ValidationError)
    expect(volunteer.communications).to be_empty
    expect(email_client).not_to have_received(:send_email)
  end

  it "records a definite gateway failure" do
    allow(email_client).to receive(:send_email).and_raise(Mailchimp::TransactionalClient::ApiError)
    expect { deliver }.to raise_error(described_class::Error, /configuration/)
    expect(volunteer.communications.last).to have_attributes(status: "failed", sent_at: nil)
  end

  it "keeps timeouts pending and warns before resending" do
    allow(email_client).to receive(:send_email).and_raise(Mailchimp::TransactionalClient::UncertainDeliveryError)
    expect { deliver }.to raise_error(described_class::Error, /before resending/)
    expect(volunteer.communications.last).to have_attributes(status: "pending", sent_at: nil)
    expect(volunteer.notes).to be_empty
  end

  [ nil, [], { "ok" => true }, { "to" => "wrong@example.org", "status" => "sent", "external_id" => "id" },
    { "to" => "unused@example.org", "status" => "sent", "external_id" => "" } ].each do |result|
    it "rejects an unconfirmed response: #{result.inspect}" do
      allow(email_client).to receive(:send_email).and_return(result)
      expect { deliver }.to raise_error(described_class::Error, /could not be confirmed/)
      expect(volunteer.communications.last).to be_pending
    end
  end
end
