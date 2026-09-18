class ProcessScheduledRemindersJob < ApplicationJob
  queue_as :default

  def perform
    FollowUpReminderScheduler.call

    ScheduledReminder.due.find_each do |reminder|
      SendReminderJob.perform_later(reminder)
    end
  end
end
