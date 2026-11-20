# Merges two volunteer records into the older one and deletes the newer one
class VolunteerMerge
  CHOICES = %w[name email phone status].freeze

  # The columns each choice copies from the record staff picked
  CHOSEN_COLUMNS = {
    "name" => %w[first_name last_name],
    "email" => %w[email],
    "phone" => %w[phone],
    "status" => %w[current_funnel_stage stage_started_at inactive_reason became_inactive_at weeks_at_inactivation]
  }.freeze

  # When something first happened, so the earlier of the two dates is kept
  EARLIEST_DATES = %w[inquiry_date first_session_attended_at application_sent_at application_submitted_at].freeze

  # Filled in from the newer record when the older one has none
  FILL_IN = %w[vicinage_id referral_source_id referred_by_volunteer_id reactivated_at].freeze

  # When both were registered for the same session, the one that says the most about what happened stays
  REGISTRATION_PRIORITY = %w[attended registered rescheduled no_show cancelled].freeze

  MOVED_RECORDS = [ Note, Communication, StatusChange, ScheduledReminder, InquiryFormSubmission ].freeze

  attr_reader :kept, :removed

  # choices maps each of CHOICES to the id of the record it comes from; anything else means the kept record
  def initialize(volunteer, other_volunteer, choices:, user:)
    @kept, @removed = [ volunteer, other_volunteer ].sort_by { |record| [ record.created_at, record.id ] }
    @choices = choices.to_h.stringify_keys
    @user = user
  end

  def call
    ActiveRecord::Base.transaction do
      [ kept, removed ].sort_by(&:id).each(&:lock!)
      move_session_registrations
      MOVED_RECORDS.each { |model| model.where(volunteer_id: removed.id).update_all(volunteer_id: kept.id) }
      cancel_repeat_reminders
      move_referrals
      keep_not_a_duplicate_decisions
      removed.reload.destroy!

      apply_choices
      kept.add_staff_note!(user: @user, note_type: :system, content: merge_note)
    end
    kept
  end

  # The record a choice comes from
  def source_for(choice)
    @choices[choice].to_s == removed.id.to_s ? removed : kept
  end

  private

  def move_session_registrations
    kept_registrations = SessionRegistration.where(volunteer_id: kept.id).index_by(&:information_session_id)
    SessionRegistration.where(volunteer_id: removed.id).find_each do |registration|
      existing = kept_registrations[registration.information_session_id]
      if existing && priority(existing) <= priority(registration)
        registration.destroy!
      else
        existing&.destroy!
        registration.update_columns(volunteer_id: kept.id)
      end
    end
  end

  def priority(registration)
    REGISTRATION_PRIORITY.index(registration.status) || REGISTRATION_PRIORITY.size
  end

  # Cancels pending reminders the kept record already has, so they aren't sent twice
  def cancel_repeat_reminders
    repeats = ScheduledReminder.where(volunteer_id: kept.id).group_by(&:communication_template_id).flat_map do |_, reminders|
      first = reminders.min_by { |reminder| [ reminder.pending? ? 1 : 0, reminder.scheduled_for, reminder.id ] }
      reminders.select(&:pending?) - [ first ]
    end
    ScheduledReminder.where(id: repeats.map(&:id))
                     .update_all(status: ScheduledReminder.statuses[:cancelled], updated_at: Time.current)
  end

  # Anyone the newer record referred now points at the kept one, and the kept one can't refer itself
  def move_referrals
    Volunteer.where(referred_by_volunteer_id: removed.id).where.not(id: kept.id)
             .update_all(referred_by_volunteer_id: kept.id)
    kept.update_columns(referred_by_volunteer_id: nil) if kept.referred_by_volunteer_id == removed.id
  end

  # Pairs staff already marked "Not a duplicate" with the newer record still apply to the kept one
  def keep_not_a_duplicate_decisions
    DuplicateDismissal.where(volunteer_id: removed.id).or(DuplicateDismissal.where(other_volunteer_id: removed.id))
                      .includes(:volunteer, :other_volunteer, :user).find_each do |dismissal|
      third = dismissal.volunteer_id == removed.id ? dismissal.other_volunteer : dismissal.volunteer
      DuplicateDismissal.dismiss!(kept, third, user: dismissal.user) unless third.id == kept.id
    end
  end

  def apply_choices
    CHOICES.each do |choice|
      source = source_for(choice)
      CHOSEN_COLUMNS.fetch(choice).each { |column| kept[column] = source[column] }
    end
    # Keep the other phone if the chosen record has none
    kept.phone = kept.phone.presence || removed.phone

    EARLIEST_DATES.each { |column| kept[column] = [ kept[column], removed[column] ].compact.min }
    FILL_IN.each { |column| kept[column] = kept[column].presence || removed[column] }
    kept.referred_by_volunteer_id = nil if kept.referred_by_volunteer_id.in?([ kept.id, removed.id ])

    chosen_stage = kept.current_funnel_stage
    kept.current_funnel_stage = kept.current_funnel_stage_was
    # Logs the status change on the timeline when the newer record's status was picked
    kept.change_status!(chosen_stage, user: @user)
    kept.save!
  end

  def merge_note
    details = [ removed.email, removed.phone.presence ].compact.join(", ")
    "Merged in a duplicate record for #{removed.full_name} (#{details}), added #{removed.created_at.strftime('%b %-d, %Y')}. " \
      "Its notes, messages, info sessions and status history are now on this profile."
  end
end
