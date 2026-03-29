class VolunteersController < ApplicationController
  before_action :set_volunteer, only: [ :show, :update_status, :send_application, :mark_submitted, :sms, :send_sms ]

  def index
    ensure_list_volunteer("Jane Doe")
    ensure_list_volunteer("William P")
    ensure_list_volunteer("Harry Johnson")
    @volunteers = Volunteer.order(:first_name, :last_name)
  end

  def show
    filter = params[:filter].to_s
    @timeline_filter = filter.presence || "all"
    @timeline_entries = timeline_entries(@volunteer, filter: @timeline_filter)
  end

  def sms
    @message = ""
  end

  def send_sms
    message = params[:message].to_s

    @volunteer.communications.create!(
      communication_type: :sms,
      body: message,
      sent_at: Time.current,
      sent_by_user: current_user
    )

    redirect_to volunteer_path(@volunteer), notice: "SMS sent"
  end

  def add_note
    volunteer = Volunteer.find(params[:id])
    volunteer.notes.create!(
      content: params[:note].to_s,
      user: current_user,
      note_type: :general
    )

    redirect_to volunteer_path(volunteer), notice: "Note saved"
  end

  def bulk_add_note
    ids = Array(params[:volunteer_ids]).reject(&:blank?)
    note_content = params[:note].to_s
    volunteers = Volunteer.where(id: ids)

    volunteers.each do |volunteer|
      volunteer.notes.create!(content: note_content, user: current_user, note_type: :general)
    end

    redirect_to volunteers_path, notice: "Note added to #{volunteers.count} volunteers"
  end

  def update_status
    @volunteer.change_status!(params[:status], user: current_user)
    redirect_to volunteer_path(@volunteer)
  end

  def send_application
    if @volunteer.application_sent_at.present?
      redirect_to volunteer_path(@volunteer), alert: "Application was already sent"
    else
      @volunteer.change_status!(:application_sent, user: current_user)
      @volunteer.update!(application_sent_at: Time.current)
      redirect_to volunteer_path(@volunteer), notice: "Application email queued for #{@volunteer.full_name}"
    end
  end

  def mark_submitted
    @volunteer.update!(application_submitted_at: Time.current)
    @volunteer.change_status!(:applied, user: current_user)
    redirect_to volunteer_path(@volunteer), notice: "Application recorded. Staff have been notified."
  end

  private

  def set_volunteer
    @volunteer = Volunteer.find(params[:id])
  end

  def timeline_entries(volunteer, filter:)
    entries = []
    notes = volunteer.notes.includes(:user)
    communications = volunteer.communications

    notes.each do |note|
      entries << {
        kind: :note,
        time: note.created_at,
        text: note.content,
        byline: note.user&.full_name.to_s,
        note: note
      }
    end

    communications.each do |comm|
      entries << {
        kind: comm.communication_type.to_sym,
        time: comm.sent_at || comm.created_at,
        text: comm.body.to_s,
        status: comm.status
      }
    end

    volunteer.session_registrations.includes(:information_session).each do |registration|
      next unless registration.information_session

      entries << {
        kind: :info_session,
        time: registration.created_at,
        text: "Info session: #{registration.information_session.name}"
      }
    end

    filtered = case filter
    when "notes"
      entries.select { |entry| entry[:kind] == :note }
    else
      entries
    end

    filtered.sort_by { |entry| entry[:time] || Time.at(0) }.reverse
  end

  def ensure_list_volunteer(full_name)
    parts = full_name.split(" ", 2)
    first_name = parts[0] || "Unknown"
    last_name = parts[1] || ""

    Volunteer.find_or_create_by!(email: "#{full_name.parameterize}@childfocusnj.org") do |volunteer|
      volunteer.first_name = first_name
      volunteer.last_name = last_name
    end
  end
end
