class Volunteer < ApplicationRecord
  enum :preferred_contact_method, { email: 0, sms: 1, both: 2 }
  enum :current_funnel_stage, { inquiry: 0, application_eligible: 1, application_sent: 2, applied: 3, inactive: 4 }
  enum :inactive_reason, { time_expired: 0, no_response: 1, cancelled: 2, duplicate: 3, other: 4 }, prefix: true

  belongs_to :referral_source, optional: true
  belongs_to :referred_by_volunteer, class_name: "Volunteer", optional: true

  has_many :session_registrations, dependent: :destroy
  has_many :information_sessions, through: :session_registrations
  has_many :communications, dependent: :destroy
  has_many :notes, dependent: :destroy
  has_many :status_changes, dependent: :destroy
  has_many :scheduled_reminders, dependent: :destroy
  has_many :inquiry_form_submissions, dependent: :nullify
  has_many :external_sync_logs, dependent: :nullify

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true, uniqueness: true

  scope :active, -> { where.not(current_funnel_stage: :inactive) }
  scope :inactive_volunteers, -> { where(current_funnel_stage: :inactive) }
  scope :application_eligible, -> { where(current_funnel_stage: :application_eligible) }
  scope :never_attended, -> { where(first_session_attended_at: nil) }

  def attended_session?
    first_session_attended_at.present?
  end

  def can_reactivate?
    inactive?
  end

  def full_name
    "#{first_name} #{last_name}"
  end
end
