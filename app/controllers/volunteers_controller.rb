class VolunteersController < ApplicationController
  before_action :set_volunteer, only: [ :show, :update, :destroy, :update_status, :send_application, :mark_submitted, :sms, :send_sms, :email, :send_email ]

  def index
    @volunteers = Volunteer.order(:first_name, :last_name)
  end

  def show
    filter = params[:filter].to_s
    @timeline_filter = filter.presence || "all"
    @timeline_entries = VolunteerTimeline.entries_for(@volunteer, filter: @timeline_filter)
  end

  def update
    if @volunteer.update(volunteer_params)
      redirect_to volunteer_path(@volunteer), notice: "Volunteer profile updated"
    else
      filter = params[:filter].to_s
      @timeline_filter = filter.presence || "all"
      @timeline_entries = VolunteerTimeline.entries_for(@volunteer, filter: @timeline_filter)
      flash.now[:alert] = @volunteer.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    name = @volunteer.full_name
    @volunteer.destroy
    redirect_to volunteers_path, notice: "#{name} was deleted."
  end

  def sms
    @message = ""
    @consent = ""
  end

  def send_sms
    communication = Sms::MailchimpOutbound.deliver!(
      volunteer: @volunteer,
      body: params[:message],
      sent_by_user: current_user,
      consent: params[:consent]
    )
    notice = communication.queued? ? "SMS queued by Mailchimp" : "SMS sent to Mailchimp"
    redirect_to volunteer_path(@volunteer), notice: notice
  rescue Sms::MailchimpOutbound::Error => e
    @message = params[:message].to_s
    @consent = params[:consent].to_s
    flash.now[:alert] = e.message
    render :sms, status: :unprocessable_entity
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

  def email
    @subject = ""
    @message = ""
  end

  def send_email
    communication = Email::MailchimpOutbound.deliver!(
      volunteer: @volunteer, subject: params[:subject], body: params[:message], sent_by_user: current_user
    )
    notice = communication.queued? ? "Email queued by Mailchimp" : "Email sent to Mailchimp"
    redirect_to volunteer_path(@volunteer), notice: notice
  rescue Email::MailchimpOutbound::Error => e
    @subject = params[:subject].to_s
    @message = params[:message].to_s
    flash.now[:alert] = e.message
    render :email, status: :unprocessable_entity
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
    communication = Email::VolunteerNotifications.application!(volunteer: @volunteer, sent_by_user: current_user)
    notice = communication.queued? ? "Application email queued by Mailchimp" : "Application email sent to Mailchimp"
    redirect_to volunteer_path(@volunteer), notice: notice
  rescue Email::MailchimpOutbound::Error => e
    redirect_to volunteer_path(@volunteer), alert: e.message
  end

  def mark_submitted
    @volunteer.mark_application_submitted!(user: current_user)
    redirect_to volunteer_path(@volunteer), notice: "Application recorded. Staff have been notified."
  end

  private

  def set_volunteer
    @volunteer = Volunteer.find(params[:id])
  end

  def volunteer_params
    params.require(:volunteer).permit(:first_name, :last_name, :email, :phone, :nj_county_id, :referral_source_id)
  end
end
