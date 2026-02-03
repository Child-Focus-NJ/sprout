class ExternalSyncLog < ApplicationRecord
  enum :sync_type, { pull: 0, push: 1, full: 2 }
  enum :sync_direction, { inbound: 0, outbound: 1 }
  enum :status, { started: 0, completed: 1, failed: 2 }

  belongs_to :volunteer, optional: true

  scope :recent, -> { order(created_at: :desc) }
  scope :successful, -> { where(status: :completed) }
  scope :failed_syncs, -> { where(status: :failed) }
end
