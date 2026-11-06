# frozen_string_literal: true

# Builds the consolidated volunteer profile timeline (notes, communications, info sessions,
# status changes) used on the volunteer show page. Extracted from VolunteersController for
# clarity and testing.
class VolunteerTimeline
  FILTER_ALL = "all"
  FILTER_NOTES = "notes"
  FILTER_STATUS_CHANGES = "status_changes"
  NOTE_CATEGORY_FILTER_PREFIX = "note_category_"
  NOTE_CATEGORY_FILTER = /\A#{NOTE_CATEGORY_FILTER_PREFIX}\d+\z/

  def self.note_category_filter(category)
    "#{NOTE_CATEGORY_FILTER_PREFIX}#{category.id}"
  end

  def self.entries_for(volunteer, filter:)
    new(volunteer, filter: filter).entries
  end

  def initialize(volunteer, filter:)
    @volunteer = volunteer
    @filter = filter.to_s.presence || FILTER_ALL
  end

  def entries
    filtered = case @filter
    when FILTER_NOTES
      raw_entries.select { |entry| entry[:kind] == :note }
    when FILTER_STATUS_CHANGES
      raw_entries.select { |entry| entry[:kind] == :status_change }
    when NOTE_CATEGORY_FILTER
      category_id = @filter.delete_prefix(NOTE_CATEGORY_FILTER_PREFIX).to_i
      raw_entries.select { |entry| entry[:kind] == :note && entry[:note].note_category_id == category_id }
    else
      raw_entries
    end

    filtered.sort_by { |entry| entry[:time] || Time.at(0) }.reverse
  end

  private

  def raw_entries
    entries = []

    @volunteer.notes.includes(:user, :note_category).each do |note|
      entries << {
        kind: :note,
        heading: note.note_category.name,
        time: note.created_at,
        text: note.content,
        byline: note.user&.full_name.to_s,
        note: note
      }
    end

    @volunteer.communications.includes(:sent_by_user).each do |comm|
      entries << {
        kind: comm.communication_type.to_sym,
        time: comm.sent_at || comm.created_at,
        text: comm.body.to_s,
        status: comm.status,
        subject: comm.subject,
        byline: comm.sent_by_user&.full_name.to_s,
        sms_to: comm.sms_to,
        external_id: comm.external_id,
        error_message: comm.error_message
      }
    end

    @volunteer.status_changes.includes(:user).each do |change|
      entries << {
        kind: :status_change,
        time: change.created_at,
        text: "#{change.from_funnel_stage} → #{change.to_funnel_stage}",
        byline: change.user&.full_name.to_s
      }
    end

    @volunteer.session_registrations.includes(:information_session).each do |registration|
      session = registration.information_session
      next unless session

      # What happened at the session, e.g. "No-show – Oct 14 session (Spring Orientation)"
      entries << {
        kind: :info_session,
        time: registration.created_at,
        text: "#{registration.status_label} – #{session.scheduled_at.strftime('%b %-d')} session (#{session.name})"
      }
    end

    @volunteer.scheduled_reminders.includes(:communication_template).each do |reminder|
      template = reminder.communication_template
      next unless template

      anchor = reminder.sent_at.presence || reminder.scheduled_for.presence || reminder.created_at
      entries << {
        kind: :scheduled_reminder,
        time: anchor,
        text: "#{template.name} — scheduled reminder for #{anchor.in_time_zone.strftime('%m/%d/%Y %H:%M')}"
      }
    end

    entries
  end
end
