class InformationSession < ApplicationRecord
  enum :session_type, { in_person: 0, virtual: 1 }

  has_many :session_registrations, dependent: :destroy
  has_many :volunteers, through: :session_registrations

  validates :scheduled_at, presence: { message: "Must include date." }
  validate :scheduled_at_must_be_in_the_future, if: -> { scheduled_at.present? }

  scope :active, -> { where(active: true) }
  scope :upcoming, -> { where("scheduled_at > ?", Time.current).order(:scheduled_at) }
  scope :past, -> { where("scheduled_at <= ?", Time.current).order(scheduled_at: :desc) }

  def spots_remaining
    return nil unless capacity
    capacity - session_registrations.where(status: [ :registered, :attended ]).count
  end

  def label
    "#{name} - #{scheduled_at.strftime('%b %d, %Y %I:%M %p')}"
  end

  def scheduled_at_must_be_in_the_future
    if scheduled_at < Time.current
      errors.add(:scheduled_at, "Information session must be in the future")
    end
  end
end
