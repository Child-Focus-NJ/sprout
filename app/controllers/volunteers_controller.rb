class VolunteersController < ApplicationController
  before_action :set_volunteer, only: [ :show, :update_status, :send_application, :mark_submitted, :sms, :send_sms ]

  def index
    ensure_list_volunteer("Jane Doe")
    ensure_list_volunteer("William P")
    ensure_list_volunteer("Harry Kane")
    @volunteers = Volunteer.order(:first_name, :last_name)
  end

  def show
    filter = params[:filter].to_s
    @timeline_filter = filter.presence || "all"
    @timeline_entries = VolunteerTimeline.entries_for(@volunteer, filter: @timeline_filter)
  end

  def sms
    @message = ""
  end

  def send_sms
    Sms::MailchimpOutbound.deliver!(
      volunteer: @volunteer,
      body: params[:message],
      sent_by_user: current_user
    )
    redirect_to volunteer_path(@volunteer), notice: "SMS sent"
  rescue Sms::MailchimpOutbound::BlankMessageError,
         Sms::MailchimpOutbound::MissingPhoneError,
         Sms::MailchimpOutbound::MessageTooLongError => e
    redirect_to sms_volunteer_path(@volunteer), alert: e.message
  rescue Sms::MailchimpOutbound::Error => e
    redirect_to volunteer_path(@volunteer), alert: e.message
  end

  def add_note
    volunteer = Volunteer.find(params[:id])
    note = volunteer.add_staff_note(
      content: params[:note].to_s,
      user: current_user,
      note_type: :general
    )
    if note.persisted?
      redirect_to volunteer_path(volunteer), notice: "Note saved"
    else
      redirect_to volunteer_path(volunteer), alert: note.errors.full_messages.to_sentence
    end
  end

  def bulk_add_note
    ids = Array(params[:volunteer_ids]).reject(&:blank?)
    note_content = params[:note].to_s
    volunteers = Volunteer.where(id: ids)

    if note_content.blank?
      redirect_to volunteers_path, alert: "Content can't be blank"
      return
    end

    if note_content.length > Note::MAX_CONTENT_LENGTH
      redirect_to volunteers_path, alert: "Content is too long (maximum is #{Note::MAX_CONTENT_LENGTH} characters)"
      return
    end

    volunteers.each do |volunteer|
      volunteer.add_staff_note(content: note_content, user: current_user, note_type: :general)
    end

    redirect_to volunteers_path, notice: "Note added to #{volunteers.count} volunteers"
  end

  def update_status
    @volunteer.change_status!(params[:status], user: current_user)
    redirect_to volunteer_path(@volunteer)
  end

  def send_application
    if @volunteer.record_application_sent!(user: current_user)
      redirect_to volunteer_path(@volunteer), notice: "Application email queued for #{@volunteer.full_name}"
    else
      redirect_to volunteer_path(@volunteer), alert: "Application was already sent"
    end
  end

  def mark_submitted
    @volunteer.mark_application_submitted!(user: current_user)
    redirect_to volunteer_path(@volunteer), notice: "Application recorded. Staff have been notified."
  end

  private

  def set_volunteer
    @volunteer = Volunteer.find(params[:id])
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
