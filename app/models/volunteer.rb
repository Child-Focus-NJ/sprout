class Volunteer < ApplicationRecord
  enum :preferred_contact_method, { email: 0, sms: 1, both: 2 }
  enum :current_funnel_stage, { inquiry: 0, application_eligible: 1, application_sent: 2, applied: 3, inactive: 4 }
  enum :inactive_reason, { time_expired: 0, no_response: 1, cancelled: 2, duplicate: 3, other: 4 }, prefix: true

  belongs_to :referral_source, optional: true
  belongs_to :referred_by_volunteer, class_name: "Volunteer", optional: true
  belongs_to :vicinage, optional: true

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

  delegate :name, to: :vicinage, prefix: true, allow_nil: true
  delegate :name, to: :referral_source, prefix: true, allow_nil: true

  scope :active, -> { where.not(current_funnel_stage: :inactive) }
  scope :inactive_volunteers, -> { where(current_funnel_stage: :inactive) }
  # `application_eligible` scope is already provided by enum `current_funnel_stage`
  scope :never_attended, -> { where(first_session_attended_at: nil) }
  scope :awaiting_application_submission, lambda {
    where(current_funnel_stage: :application_sent).order(application_sent_at: :asc)
  }
  # Case-insensitive name search; every word typed must match the first or last name,
  # so "harry kane" and "kane" both find Harry Kane.
  scope :name_matching, lambda { |query|
    query.to_s.split.reduce(all) do |relation, term|
      relation.where("volunteers.first_name ILIKE :term OR volunteers.last_name ILIKE :term",
                     term: "%#{sanitize_sql_like(term)}%")
    end
  }

  after_save :cancel_pending_reminders_if_applied

  def attended_session?
    first_session_attended_at.present?
  end

  def stage_started_at
    case current_funnel_stage.to_sym
    when :inquiry then inquiry_date || created_at
    when :application_eligible then first_session_attended_at
    when :application_sent then application_sent_at
    end
  end

  def days_in_current_stage
    started_at = stage_started_at
    return nil if started_at.blank?

    ((Time.current - started_at) / 1.day).floor
  end

  def status
    return :attended_session if attended_session?

    current_funnel_stage.to_sym
  end

  def can_reactivate?
    inactive?
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  # Staff-authored or system-captured notes (profile form, bulk list, communication callbacks).
  def add_staff_note(content:, user:, note_type: :general, note_category: nil)
    notes.create(content: content.to_s, user: user, note_type: note_type, note_category: note_category)
  end

  def add_staff_note!(content:, user:, note_type: :general, note_category: nil)
    notes.create!(content: content.to_s, user: user, note_type: note_type, note_category: note_category)
  end

  class OutcomeNoteError < StandardError; end

  def add_note_with_outcome!(content:, user:, note_category:, information_session: nil, new_information_session: nil)
    ActiveRecord::Base.transaction do
      note = add_staff_note!(content: content, user: user, note_category: note_category)
      registration = registration_for_outcome!(information_session, note_category) if note_category.session_outcome?

      case note_category.key
      when "attended_info_session"
        record_attendance!(registration, user: user)
      when "no_show", "cancelled"
        registration.update!(status: note_category.key)
      when "rescheduled"
        reschedule_registration!(registration, new_information_session)
      when NoteCategory::DEACTIVATED_KEY
        change_status!(:inactive, user: user)
      end

      note
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

  def finalize_check_in_for_session!(information_session, user:)
    registration = SessionRegistration.find_or_initialize_by(
      volunteer: self,
      information_session: information_session
    )
    registration.status = :attended
    registration.checked_in_at = Time.current
    registration.save!

    update!(first_session_attended_at: Time.current) unless first_session_attended_at.present?
    change_status!(:application_eligible, user: user, trigger: :event) unless application_sent? || applied?
  end

  # Staff action or automation: move to application_sent and record send time (idempotent on duplicate send).
  def record_application_sent!(user:, sent_at: Time.current)
    return false if application_sent_at.present?

    ActiveRecord::Base.transaction do
      change_status!(:application_sent, user: user) unless applied? || inactive?
      update!(application_sent_at: sent_at)
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

  def registration_for_outcome!(information_session, note_category)
    raise OutcomeNoteError, "Choose the session this note is about" if information_session.nil?

    registration = session_registrations.find_by(information_session: information_session) ||
      raise(OutcomeNoteError, "#{full_name} isn't registered for that session")
    if registration.attended? && note_category.key != "attended_info_session"
      raise OutcomeNoteError, "#{full_name} already attended that session, so it can't be marked #{note_category.name}"
    end

    registration
  end

  def record_attendance!(registration, user:)
    registration.update!(status: :attended, checked_in_at: registration.checked_in_at || Time.current)
    update!(first_session_attended_at: Time.current) if first_session_attended_at.blank?
    change_status!(:application_eligible, user: user, trigger: :event) if inquiry?
  end

  def reschedule_registration!(registration, new_information_session)
    raise OutcomeNoteError, "Choose the session they're rescheduling to" if new_information_session.nil?
    if new_information_session == registration.information_session
      raise OutcomeNoteError, "Choose a different session to reschedule to"
    end

    registration.update!(status: :rescheduled)
    session_registrations.find_or_initialize_by(information_session: new_information_session)
                         .update!(status: :registered)
  end

  def cancel_pending_reminders_if_applied
    return unless saved_change_to_current_funnel_stage? && applied?

    scheduled_reminders.pending_reminders.update_all(status: ScheduledReminder.statuses[:cancelled])
  end
end
