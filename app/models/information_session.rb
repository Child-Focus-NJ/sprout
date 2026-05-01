class InformationSession < ApplicationRecord
  enum :session_type, { in_person: 0, virtual: 1 }

  LOCATION_CHOICES = ["415 Hamburg Turnpike", "Zoom"].freeze
  VALID_URL_REGEX = /\Ahttps?:\/\/.+\z/i

  attribute :capacity, :integer, default: 10

  belongs_to :created_by_user, class_name: "User", optional: true

  has_many :session_registrations, dependent: :destroy
  has_many :volunteers, through: :session_registrations

  validates :scheduled_at, presence: { message: "Must include date." }
  validate :scheduled_at_must_be_in_the_future, if: -> { scheduled_at.present? }
  validates :location, presence: true, inclusion: { in: LOCATION_CHOICES }
  validates :zoom_link,
    presence: true,
    format: { with: VALID_URL_REGEX, message: "must be a URL starting with http:// or https://" },
    if: :zoom_location?

  before_validation :sync_from_location

  scope :active,    -> { where(active: true) }
  scope :upcoming,  -> { where("scheduled_at > ?", Time.current).order(:scheduled_at) }
  scope :past,      -> { where("scheduled_at <= ?", Time.current).order(scheduled_at: :desc) }

  def spots_remaining
    capacity && capacity - session_registrations.where(status: [:registered, :attended]).count
  end

  def label
    "#{name} - #{scheduled_at.strftime('%b %d, %Y %I:%M %p')}"
  end

  def zoom_location?
    location == "Zoom"
  end

  private

  def sync_from_location
    self.session_type = zoom_location? ? :virtual : :in_person
    self.zoom_link = nil unless zoom_location?
  end

  def scheduled_at_must_be_in_the_future
    if scheduled_at < Time.current
      errors.add(:scheduled_at, "Information session must be in the future")
    end
  end
end