# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sms::MailchimpOutbound do
  include_context "Mailchimp SMS enabled"

  let(:user) { create(:user) }
  let(:volunteer) { create(:volunteer, phone: "(201) 555-0123") }
  let(:client) { instance_double(Mailchimp::TransactionalClient) }
  let(:result) { { "status" => "sent", "external_id" => "spec-sms-id", "to" => "+12015550123" } }

  before do
    allow(Mailchimp::TransactionalClient).to receive(:new).and_return(client)
    allow(client).to receive(:send_sms).and_return(result)
  end

  def deliver(body: "Hello", consent: "onetime")
    described_class.deliver!(volunteer: volunteer, body: body, consent: consent, sent_by_user: user)
  end

  it "saves the provider ID, recipient, consent, sender, and sent status without claiming delivery" do
    comm = deliver(body: " Hello ")
    expect(client).to have_received(:send_sms).with(to: "+12015550123", message: "Hello", consent: "onetime")
    expect(comm.reload).to have_attributes(status: "sent", external_id: "spec-sms-id", sms_to: "+12015550123",
      sms_consent: "onetime", sent_by_user: user, body: "Hello")
    expect(comm.sent_at).to be_present
    expect(comm).not_to be_delivered
    expect(volunteer.notes.where(note_type: :communication).count).to eq(1)
  end

  %w[queued scheduled].each do |status|
    it "records #{status} without a sent time or a sent note" do
      result["status"] = status
      comm = deliver
      expect(comm).to be_queued
      expect(comm.sent_at).to be_nil
      expect(comm.external_id).to eq("spec-sms-id")
      expect(volunteer.notes).to be_empty
    end
  end

  %w[rejected invalid].each do |status|
    it "records #{status} as failed, even when the provider returns HTTP success" do
      result.merge!("status" => status, "reject_reason" => "unsub")
      expect { deliver }.to raise_error(described_class::Error, /rejected/)
      comm = volunteer.communications.last
      expect(comm).to have_attributes(status: "failed", sent_at: nil, external_id: "spec-sms-id")
      expect(comm.error_message).to include("unsub")
      expect(volunteer.notes).to be_empty
    end
  end

  it "does not invent a send when SMS is disabled" do
    ENV["SPROUT_SMS_MAILCHIMP_ENABLED"] = "false"
    expect { deliver }.to raise_error(described_class::ConfigurationError)
    expect(volunteer.communications).to be_empty
    expect(client).not_to have_received(:send_sms)
  end

  it "records a configuration failure without a sent note" do
    allow(client).to receive(:send_sms).and_raise(Mailchimp::TransactionalClient::ConfigurationError, "No key")
    expect { deliver }.to raise_error(described_class::Error, /configuration/)
    expect(volunteer.communications.last).to have_attributes(status: "failed", sent_at: nil)
    expect(volunteer.notes).to be_empty
  end

  it "keeps an uncertain attempt pending and warns against blindly resending" do
    allow(client).to receive(:send_sms).and_raise(Mailchimp::TransactionalClient::UncertainDeliveryError)
    expect { deliver }.to raise_error(described_class::Error, /before resending/)
    expect(volunteer.communications.last).to have_attributes(status: "pending", sent_at: nil, external_id: nil)
    expect(volunteer.notes).to be_empty
  end

  [ { "status" => "ok" }, { "ok" => true }, nil, [],
    { "status" => "sent", "external_id" => "", "to" => "+12015550123" },
    { "status" => "sent", "external_id" => "spec-sms-id", "to" => "+12015550999" } ].each do |invalid_result|
    it "does not accept a stub, malformed result, or mismatched recipient: #{invalid_result.inspect}" do
      allow(client).to receive(:send_sms).and_return(invalid_result)
      expect { deliver }.to raise_error(described_class::Error, /could not be confirmed/)
      expect(volunteer.communications.last).to have_attributes(status: "pending", sent_at: nil)
    end
  end

  it "validates message, phone, and consent before attempting a send" do
    expect { deliver(body: " ") }.to raise_error(described_class::BlankMessageError)
    expect { deliver(body: "a" * 321) }.to raise_error(described_class::MessageTooLongError)
    expect { deliver(consent: nil) }.to raise_error(described_class::MissingConsentError)
    expect { deliver(consent: "true") }.to raise_error(described_class::MissingConsentError)
    volunteer.phone = nil
    expect { deliver }.to raise_error(described_class::MissingPhoneError)
    volunteer.phone = "000"
    expect { deliver }.to raise_error(described_class::InvalidPhoneError)
    expect(volunteer.communications).to be_empty
    expect(client).not_to have_received(:send_sms)
  end

  describe ".normalize_phone" do
    it "preserves country codes and accepts formatted US numbers" do
      expect(described_class.normalize_phone("(201) 555-0123")).to eq("+12015550123")
      expect(described_class.normalize_phone("1-201-555-0123")).to eq("+12015550123")
      expect(described_class.normalize_phone("+44 7700 900123")).to eq("+447700900123")
    end

    it "rejects ambiguous, overlong, and malformed numbers instead of truncating them" do
      [ "442015550123", "+0123456789", "+1201555012345678", "2015550123 ext 45", "abc2015550123" ].each do |phone|
        expect { described_class.normalize_phone(phone) }.to raise_error(described_class::InvalidPhoneError)
      end
    end
  end
end
