class InformationSession < ApplicationRecord
  enum :session_type, { in_person: 0, virtual: 1 }

  has_many :session_registrations, dependent: :destroy
  has_many :volunteers, through: :session_registrations

  validates :scheduled_at, presence: true

  scope :active, -> { where(active: true) }
  scope :upcoming, -> { where("scheduled_at > ?", Time.current).order(:scheduled_at) }
  scope :past, -> { where("scheduled_at <= ?", Time.current).order(scheduled_at: :desc) }

  def spots_remaining
    return nil unless capacity
    capacity - session_registrations.where(status: [ :registered, :attended ]).count
  end
end
