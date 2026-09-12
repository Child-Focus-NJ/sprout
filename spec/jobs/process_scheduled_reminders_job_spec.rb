require "rails_helper"

RSpec.describe ProcessScheduledRemindersJob, type: :job do
  include ActiveJob::TestHelper

  let!(:template) do
    CommunicationTemplate.create!(
      name: "30-day nudge",
      body: "Hi {{first_name}}, just checking in.",
      funnel_stage: :inquiry,
      trigger_type: :interval,
      interval_days: 30
    )
  end

  it "schedules newly-stalled volunteers, then enqueues SendReminderJob for everything due" do
    volunteer = create(:volunteer, current_funnel_stage: :inquiry, inquiry_date: 31.days.ago)

    expect {
      described_class.perform_now
    }.to have_enqueued_job(SendReminderJob).with { |reminder| expect(reminder.volunteer).to eq(volunteer) }
  end

  it "sends the due reminder end-to-end when enqueued jobs are performed" do
    create(:volunteer, current_funnel_stage: :inquiry, inquiry_date: 31.days.ago)

    perform_enqueued_jobs do
      described_class.perform_now
    end

    expect(ScheduledReminder.sole).to be_sent
    expect(ActionMailer::Base.deliveries.size).to eq(1)
  end

  it "does not enqueue anything when a reminder is scheduled in the future" do
    volunteer = create(:volunteer, current_funnel_stage: :inquiry, inquiry_date: 31.days.ago)
    ScheduledReminder.create!(volunteer: volunteer, communication_template: template, scheduled_for: 1.day.from_now)

    expect { described_class.perform_now }.not_to have_enqueued_job(SendReminderJob)
  end
end
