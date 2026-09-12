require "rails_helper"

RSpec.describe FollowUpReminderScheduler do
  def template_for(stage:, days:)
    CommunicationTemplate.create!(
      name: "#{stage} #{days}-day nudge",
      body: "It's been #{days} days.",
      funnel_stage: stage,
      trigger_type: :interval,
      interval_days: days
    )
  end

  describe ".call" do
    it "schedules a reminder once a stalled inquiry crosses the 30-day threshold" do
      template = template_for(stage: :inquiry, days: 30)
      volunteer = create(:volunteer, current_funnel_stage: :inquiry, inquiry_date: 31.days.ago)

      expect { described_class.call }.to change(ScheduledReminder, :count).by(1)

      reminder = ScheduledReminder.last
      expect(reminder.volunteer).to eq(volunteer)
      expect(reminder.communication_template).to eq(template)
      expect(reminder).to be_pending
    end

    it "does not schedule a reminder before the threshold is reached" do
      template_for(stage: :inquiry, days: 30)
      create(:volunteer, current_funnel_stage: :inquiry, inquiry_date: 10.days.ago)

      expect { described_class.call }.not_to change(ScheduledReminder, :count)
    end

    it "does not schedule the same template twice for the same volunteer" do
      template_for(stage: :inquiry, days: 30)
      create(:volunteer, current_funnel_stage: :inquiry, inquiry_date: 45.days.ago)

      described_class.call
      expect { described_class.call }.not_to change(ScheduledReminder, :count)
    end

    it "schedules independently for each crossed threshold" do
      template_for(stage: :inquiry, days: 30)
      template_for(stage: :inquiry, days: 60)
      create(:volunteer, current_funnel_stage: :inquiry, inquiry_date: 65.days.ago)

      expect { described_class.call }.to change(ScheduledReminder, :count).by(2)
    end

    it "keys off first_session_attended_at for volunteers awaiting an application" do
      template = template_for(stage: :application_eligible, days: 30)
      volunteer = create(:volunteer, current_funnel_stage: :application_eligible, first_session_attended_at: 31.days.ago)

      described_class.call

      expect(volunteer.scheduled_reminders.sole.communication_template).to eq(template)
    end

    it "keys off application_sent_at for volunteers who haven't submitted" do
      template = template_for(stage: :application_sent, days: 30)
      volunteer = create(:volunteer, current_funnel_stage: :application_sent, application_sent_at: 31.days.ago)

      described_class.call

      expect(volunteer.scheduled_reminders.sole.communication_template).to eq(template)
    end

    it "ignores inactive templates" do
      template_for(stage: :inquiry, days: 30).update!(active: false)
      create(:volunteer, current_funnel_stage: :inquiry, inquiry_date: 45.days.ago)

      expect { described_class.call }.not_to change(ScheduledReminder, :count)
    end

    it "never nags volunteers who have applied or gone inactive" do
      template_for(stage: :inquiry, days: 30)
      create(:volunteer, current_funnel_stage: :applied, inquiry_date: 90.days.ago)
      create(:volunteer, current_funnel_stage: :inactive, inquiry_date: 90.days.ago)

      expect { described_class.call }.not_to change(ScheduledReminder, :count)
    end
  end
end
