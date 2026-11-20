require "rails_helper"

RSpec.describe SendTemplateEmailJob, type: :job do
  include_context "Mailchimp email enabled"

  let(:volunteer) { create(:volunteer, first_name: "Jane", email: "jane@childfocusnj.org") }
  let(:template) do
    CommunicationTemplate.create!(
      name: "Invite", subject: "Hi {{first_name}}", body: "Hello {{first_name}}",
      template_type: :email, funnel_stage: :inquiry, trigger_type: :manual, active: true
    )
  end
  let(:communication) { Email::TemplateDelivery.record!(volunteer: volunteer, template: template) }

  it "sends the recorded email and marks it sent" do
    described_class.perform_now(communication.id)

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq([ "jane@childfocusnj.org" ])
    expect(mail.subject).to eq("Hi Jane")
    expect(communication.reload).to be_sent
    expect(communication.sent_at).to be_present
  end

  it "does not send an email that is no longer pending" do
    communication.update!(status: :sent)

    described_class.perform_now(communication.id)

    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "skips an email another person has already claimed" do
    communication.update!(status: :sending)

    described_class.perform_now(communication.id)

    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "marks the email failed without sending if email was turned off after it was queued" do
    ENV["SPROUT_EMAIL_MAILCHIMP_ENABLED"] = "false"

    described_class.perform_now(communication.id)

    expect(ActionMailer::Base.deliveries).to be_empty
    expect(communication.reload).to be_failed
    expect(communication.error_message).to eq(Email::DISABLED_MESSAGE)
  end

  it "leaves the email as sending, not resent, if it went out but marking it sent failed" do
    allow(Communication).to receive(:find).with(communication.id).and_return(communication)
    allow(communication).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)

    expect { described_class.perform_now(communication.id) }.to raise_error(ActiveRecord::RecordInvalid)
    described_class.perform_now(communication.id)

    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(communication.reload).to be_sending
  end

  it "marks the email failed with reason when sending fails" do
    allow(TemplateMailer).to receive(:follow_up).and_raise(StandardError, "SMTP down")

    expect { described_class.perform_now(communication.id) }.to raise_error(StandardError, "SMTP down")

    expect(communication.reload).to be_failed
    expect(communication.error_message).to eq("SMTP down")
  end
end
