# frozen_string_literal: true

require "rails_helper"

RSpec.describe ScheduledReminder, type: :model do
  let(:template) do
    CommunicationTemplate.create!(
      name: "2-week follow-up",
      body: "Hi, just following up on your inquiry.",
      funnel_stage: :inquiry,
      trigger_type: :interval,
      interval_weeks: 2
    )
  end
  let(:volunteer) { create(:volunteer, current_funnel_stage: :inquiry) }

  describe "validations" do
    it "is invalid without a scheduled_for date" do
      reminder = ScheduledReminder.new(volunteer: volunteer, communication_template: template, status: :pending)
      expect(reminder).not_to be_valid
      expect(reminder.errors[:scheduled_for]).to be_present
    end

    it "is valid with all required fields" do
      reminder = ScheduledReminder.new(
        volunteer: volunteer,
        communication_template: template,
        scheduled_for: 2.weeks.from_now,
        status: :pending
      )
      expect(reminder).to be_valid
    end
  end

  describe "statuses" do
    it "defaults to pending" do
      reminder = ScheduledReminder.create!(
        volunteer: volunteer,
        communication_template: template,
        scheduled_for: 2.weeks.from_now
      )
      expect(reminder).to be_pending
    end

    it "can be marked sent" do
      reminder = ScheduledReminder.create!(
        volunteer: volunteer,
        communication_template: template,
        scheduled_for: 1.week.from_now
      )
      reminder.sent!
      expect(reminder).to be_sent
    end

    it "can be cancelled" do
      reminder = ScheduledReminder.create!(
        volunteer: volunteer,
        communication_template: template,
        scheduled_for: 1.week.from_now
      )
      reminder.cancelled!
      expect(reminder).to be_cancelled
    end
  end

  describe ".due" do
    it "returns pending reminders scheduled in the past or now" do
      overdue = ScheduledReminder.create!(volunteer: volunteer, communication_template: template, scheduled_for: 1.day.ago, status: :pending)
      future = ScheduledReminder.create!(volunteer: volunteer, communication_template: template, scheduled_for: 1.day.from_now, status: :pending)

      expect(ScheduledReminder.due).to include(overdue)
      expect(ScheduledReminder.due).not_to include(future)
    end

    it "does not return already sent reminders" do
      sent = ScheduledReminder.create!(volunteer: volunteer, communication_template: template, scheduled_for: 1.day.ago, status: :sent)
      expect(ScheduledReminder.due).not_to include(sent)
    end

    it "does not return cancelled reminders" do
      cancelled = ScheduledReminder.create!(volunteer: volunteer, communication_template: template, scheduled_for: 1.day.ago, status: :cancelled)
      expect(ScheduledReminder.due).not_to include(cancelled)
    end
  end

  describe ".upcoming" do
    it "returns pending reminders scheduled in the future, ordered by date" do
      sooner = ScheduledReminder.create!(volunteer: volunteer, communication_template: template, scheduled_for: 1.week.from_now, status: :pending)
      later = ScheduledReminder.create!(volunteer: volunteer, communication_template: template, scheduled_for: 4.weeks.from_now, status: :pending)

      expect(ScheduledReminder.upcoming.to_a).to eq([ sooner, later ])
    end
  end

  describe "US3: pending reminders cancelled when volunteer reaches applied" do
    it "cancels all pending reminders when volunteer status becomes applied" do
      reminder = ScheduledReminder.create!(
        volunteer: volunteer,
        communication_template: template,
        scheduled_for: 2.weeks.from_now,
        status: :pending
      )

      volunteer.update!(current_funnel_stage: :applied)

      expect(reminder.reload).to be_cancelled
    end

    it "does not cancel already sent reminders when volunteer reaches applied" do
      sent_reminder = ScheduledReminder.create!(
        volunteer: volunteer,
        communication_template: template,
        scheduled_for: 1.week.ago,
        status: :sent
      )

      volunteer.update!(current_funnel_stage: :applied)

      expect(sent_reminder.reload).to be_sent
    end
  end
end
