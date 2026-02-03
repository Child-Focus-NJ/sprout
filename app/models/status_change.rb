class StatusChange < ApplicationRecord
  enum :trigger, { system: 0, manual: 1, event: 2 }

  belongs_to :volunteer
  belongs_to :user, optional: true

  scope :recent, -> { order(created_at: :desc) }
  scope :for_volunteer, ->(volunteer) { where(volunteer: volunteer) }
end
