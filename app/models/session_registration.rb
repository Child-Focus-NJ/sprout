class SessionRegistration < ApplicationRecord
  enum :status, { registered: 0, attended: 1, no_show: 2, cancelled: 3, rescheduled: 4 }

  belongs_to :volunteer
  belongs_to :information_session

  validates :volunteer_id, uniqueness: { scope: :information_session_id, message: "already registered for this session" }

  # Outcomes where the volunteer didn't make it to the session they signed up for
  MISSED_STATUSES = %w[no_show cancelled rescheduled].freeze

  scope :active, -> { where(status: [ :registered, :attended ]) }
  scope :missed, -> { where(status: MISSED_STATUSES) }

  def status_label
    no_show? ? "No-show" : status.humanize
  end
end
