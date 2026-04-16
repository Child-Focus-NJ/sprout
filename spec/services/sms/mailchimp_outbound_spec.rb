# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sms::MailchimpOutbound do
  let(:user) { create(:user) }
  let(:volunteer) { create(:volunteer, phone: "5551234567") }

  describe ".deliver!" do
    context "when Mailchimp/Lambda is not enabled (default)" do
      before do
        ENV.delete("SPROUT_SMS_MAILCHIMP_ENABLED")
        ENV.delete("API_GATEWAY_URL")
      end

      it "records an SMS locally with sent time and delivered-equivalent status" do
        comm = described_class.deliver!(volunteer: volunteer, body: "Hello", sent_by_user: user)

        comm.reload
        expect(comm).to be_sms
        expect(comm.sent_at).to be_present
        expect(comm.delivered?).to be true
        expect(comm.body).to eq("Hello")
      end

      it "creates a staff timeline note" do
        expect do
          described_class.deliver!(volunteer: volunteer, body: "Hi", sent_by_user: user)
        end.to change { volunteer.notes.count }.by(1)
      end

      it "raises when message is blank" do
        expect do
          described_class.deliver!(volunteer: volunteer, body: "   ", sent_by_user: user)
        end.to raise_error(Sms::MailchimpOutbound::BlankMessageError)
      end

      it "raises when message exceeds the max length" do
        expect do
          described_class.deliver!(volunteer: volunteer, body: ("a" * 321), sent_by_user: user)
        end.to raise_error(Sms::MailchimpOutbound::MessageTooLongError)
      end

      it "raises when phone is missing" do
        volunteer.update!(phone: nil)
        expect do
          described_class.deliver!(volunteer: volunteer, body: "Hi", sent_by_user: user)
        end.to raise_error(Sms::MailchimpOutbound::MissingPhoneError)
      end
    end

    context "when Mailchimp/Lambda is enabled" do
      let(:lambda_client) { instance_double(Aws::LambdaClient) }

      before do
        ENV["SPROUT_SMS_MAILCHIMP_ENABLED"] = "true"
        ENV["API_GATEWAY_URL"] = "http://gateway.test"
        allow(Aws::LambdaClient).to receive(:new).and_return(lambda_client)
      end

      after do
        ENV.delete("SPROUT_SMS_MAILCHIMP_ENABLED")
        ENV.delete("API_GATEWAY_URL")
      end

      it "calls Lambda send_sms and marks the communication delivered" do
        allow(lambda_client).to receive(:send_sms).and_return({ "ok" => true })

        comm = described_class.deliver!(volunteer: volunteer, body: "Via API", sent_by_user: user)

        expect(lambda_client).to have_received(:send_sms).with(
          hash_including(to: "+15551234567", message: "Via API")
        )
        comm.reload
        expect(comm.delivered?).to be true
        expect(comm.sent_at).to be_present
      end

      it "marks failed and raises on Lambda error" do
        allow(lambda_client).to receive(:send_sms).and_raise(Aws::LambdaClient::LambdaError.new("boom"))

        expect do
          described_class.deliver!(volunteer: volunteer, body: "X", sent_by_user: user)
        end.to raise_error(Sms::MailchimpOutbound::Error)

        expect(volunteer.communications.sms.last).to be_failed
        expect(volunteer.communications.sms.last.sent_at).to be_nil
      end
    end
  end
end
