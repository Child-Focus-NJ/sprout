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
  # `application_eligible` scope is already provided by enum `current_funnel_stage`
  scope :never_attended, -> { where(first_session_attended_at: nil) }
  scope :awaiting_application_submission, lambda {
    where(current_funnel_stage: :application_sent).order(application_sent_at: :asc)
  }

  after_save :cancel_pending_reminders_if_applied

  def attended_session?
    first_session_attended_at.present?
  end

  # User Story 9 expects a `status` method that reflects attendance.
  # We keep funnel stage tracking in `current_funnel_stage`, but expose an
  # attendance-focused status for the sign-in flow.
  def status
    return :attended_session if attended_session?

    current_funnel_stage
  end

  def can_reactivate?
    inactive?
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  # Single label for the profile "Current status" block (matches user-facing copy elsewhere).
  def profile_status_label
    if applied?
      "Application submitted"
    elsif application_sent?
      "Application sent"
    else
      current_funnel_stage.to_s.humanize
    end
  end

  def change_status!(new_stage, user: nil, trigger: :manual)
    old_stage = current_funnel_stage
    new_stage_key = new_stage.to_s
    return if old_stage == new_stage_key

    update!(current_funnel_stage: new_stage_key)
    status_changes.create!(
      from_funnel_stage: old_stage.humanize,
      to_funnel_stage: new_stage_key.humanize,
      trigger: trigger,
      user: user
    )
  end

  # Info session check-in: mark registration attended, set first-session time, advance to eligible.
  # Application is sent separately (staff action or automation); see +send_application+.
  def finalize_check_in_for_session!(information_session, user:)
    registration = SessionRegistration.find_or_initialize_by(
      volunteer: self,
      information_session: information_session
    )
    registration.status = :attended
    registration.checked_in_at = Time.current
    registration.save!

    update!(first_session_attended_at: Time.current) unless first_session_attended_at.present?
    change_status!(:application_eligible, user: user, trigger: :event)
  end

  # Staff action or automation: move to application_sent and record send time (idempotent on duplicate send).
  def record_application_sent!(user:)
    return false if application_sent_at.present?

    ActiveRecord::Base.transaction do
      change_status!(:application_sent, user: user)
      update!(application_sent_at: Time.current)
    end
    true
  end

  def mark_application_submitted!(user:)
    ActiveRecord::Base.transaction do
      update!(application_submitted_at: Time.current)
      change_status!(:applied, user: user)
    end
  end

  private

  def cancel_pending_reminders_if_applied
    return unless saved_change_to_current_funnel_stage? && applied?

    scheduled_reminders.pending_reminders.update_all(status: ScheduledReminder.statuses[:cancelled])
  end
end
