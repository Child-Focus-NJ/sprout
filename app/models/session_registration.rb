class SessionRegistration < ApplicationRecord
  enum :status, { registered: 0, attended: 1, no_show: 2, cancelled: 3, rescheduled: 4 }

  belongs_to :volunteer
  belongs_to :information_session

  validates :volunteer_id, uniqueness: { scope: :information_session_id, message: "already registered for this session" }

  scope :active, -> { where(status: [ :registered, :attended ]) }
end
