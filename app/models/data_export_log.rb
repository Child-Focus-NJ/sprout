class DataExportLog < ApplicationRecord
  enum :trigger, { manual: 0, scheduled: 1 }
  enum :status, { started: 0, completed: 1, failed: 2 }

  belongs_to :user, optional: true

  scope :recent, -> { order(created_at: :desc) }
end
