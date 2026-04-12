class InformationSession < ApplicationRecord
  enum :session_type, { in_person: 0, virtual: 1 }

  LOCATION_CHOICES = ["415 Hamburg Turnpike", "Zoom"].freeze

  attribute :capacity, :integer, default: 10

  belongs_to :created_by_user, class_name: "User", optional: true

  has_many :session_registrations, dependent: :destroy
  has_many :volunteers, through: :session_registrations

  validates :scheduled_at, presence: { message: "Must include date." }
  validate :scheduled_at_must_be_in_the_future, if: -> { scheduled_at.present? }
  validates :location, presence: true, inclusion: { in: LOCATION_CHOICES }
  validates :zoom_link,
    presence: true,
    format: {
      with: /\Ahttps?:\/\/.+/i,
      message: "must be a URL starting with http:// or https://"
    },
    if: :zoom_location?

  before_validation :sync_session_type_from_location
  before_validation :ensure_capacity_default
  before_save :clear_zoom_link_unless_zoom

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

  def zoom_location?
    location == "Zoom"
  end

  def sync_session_type_from_location
    self.session_type = zoom_location? ? :virtual : :in_person
  end

  def clear_zoom_link_unless_zoom
    self.zoom_link = nil unless zoom_location?
  end

  def ensure_capacity_default
    self.capacity = 10 if capacity.blank?
  end
end
