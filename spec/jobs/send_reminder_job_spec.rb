require "rails_helper"

RSpec.describe SendReminderJob, type: :job do
  let(:volunteer) { create(:volunteer, first_name: "Jane", email: "jane@childfocusnj.org") }
  let(:template) do
    CommunicationTemplate.create!(
      name: "30-day nudge",
      subject: "Still there, {{first_name}}?",
      body: "Hi {{first_name}}, just checking in.",
      funnel_stage: :inquiry,
      trigger_type: :interval,
      interval_days: 30
    )
  end
  let(:reminder) do
    ScheduledReminder.create!(volunteer: volunteer, communication_template: template, scheduled_for: Time.current)
  end

  it "delivers the rendered template to the volunteer" do
    described_class.perform_now(reminder)

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to include("jane@childfocusnj.org")
    expect(mail.subject).to eq("Still there, Jane?")
    expect(mail.body.encoded).to include("Hi Jane, just checking in.")
  end

  it "records a Communication linked to the volunteer and template" do
    expect { described_class.perform_now(reminder) }.to change(Communication, :count).by(1)

    communication = Communication.last
    expect(communication.volunteer).to eq(volunteer)
    expect(communication.communication_template).to eq(template)
    expect(communication.subject).to eq("Still there, Jane?")
    expect(communication).to be_sent
  end

  it "marks the reminder sent" do
    described_class.perform_now(reminder)
    expect(reminder.reload).to be_sent
    expect(reminder.sent_at).to be_present
  end

  it "does nothing for a reminder that is no longer pending" do
    reminder.update!(status: :cancelled)

    expect { described_class.perform_now(reminder) }.not_to change(Communication, :count)
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "marks the reminder skipped and re-raises when delivery fails" do
    allow(TemplateMailer).to receive(:follow_up).and_raise(StandardError, "SMTP down")

    expect { described_class.perform_now(reminder) }.to raise_error(StandardError, "SMTP down")

    expect(reminder.reload).to be_skipped
    expect(reminder.skip_reason).to eq("SMTP down")
  end
end
