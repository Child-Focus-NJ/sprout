# frozen_string_literal: true

# Builds the consolidated volunteer profile timeline (notes, communications, info sessions,
# status changes) used on the volunteer show page. Extracted from VolunteersController for
# clarity and testing.
class VolunteerTimeline
  FILTER_ALL = "all"
  FILTER_NOTES = "notes"
  FILTER_STATUS_CHANGES = "status_changes"

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
    else
      raw_entries
    end

    filtered.sort_by { |entry| entry[:time] || Time.at(0) }.reverse
  end

  private

  def raw_entries
    entries = []

    @volunteer.notes.includes(:user).each do |note|
      entries << {
        kind: :note,
        time: note.created_at,
        text: note.content,
        byline: note.user&.full_name.to_s,
        note: note
      }
    end

    @volunteer.communications.each do |comm|
      entries << {
        kind: comm.communication_type.to_sym,
        time: comm.sent_at || comm.created_at,
        text: comm.body.to_s,
        status: comm.status
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
      next unless registration.information_session

      entries << {
        kind: :info_session,
        time: registration.created_at,
        text: registration.information_session.name
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
