class ScheduledReminder < ApplicationRecord
  enum :status, { pending: 0, sent: 1, cancelled: 2, skipped: 3 }

  belongs_to :volunteer
  belongs_to :communication_template

  validates :scheduled_for, presence: true

  scope :pending_reminders, -> { where(status: :pending) }
  scope :due, -> { pending_reminders.where("scheduled_for <= ?", Time.current) }
  scope :upcoming, -> { pending_reminders.where("scheduled_for > ?", Time.current).order(:scheduled_for) }
end
