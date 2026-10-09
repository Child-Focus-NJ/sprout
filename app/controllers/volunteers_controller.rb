class VolunteersController < ApplicationController
  before_action :set_volunteer, only: [ :show, :update, :destroy, :update_status, :send_application, :mark_submitted, :send_sms ]

  def index
    @filters = list_filter_params
    @counties = NjCounty.alphabetical
    @total_count = Volunteer.count

    volunteers = Volunteer.includes(:nj_county).order(:first_name, :last_name)
    volunteers = volunteers.name_matching(@filters[:q]) if @filters[:q]
    volunteers = volunteers.where(current_funnel_stage: @filters[:status]) if @filters[:status]
    volunteers = volunteers.where(nj_county_id: @filters[:county_id]) if @filters[:county_id]
    @volunteers = volunteers
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

  def send_sms
    Sms::MailchimpOutbound.deliver!(
      volunteer: @volunteer,
      body: params[:message],
      sent_by_user: current_user
    )
    redirect_to return_path_for(@volunteer), notice: "SMS sent to #{@volunteer.full_name}"
  rescue Sms::MailchimpOutbound::Error => e
    redirect_to return_path_for(@volunteer), alert: e.message
  end

  def add_note
    volunteer = Volunteer.find(params[:id])
    note = volunteer.add_staff_note(
      content: params[:note].to_s,
      user: current_user,
      note_type: :general
    )
    if note.persisted?
      redirect_to return_path_for(volunteer), notice: "Note saved for #{volunteer.full_name}"
    else
      redirect_to return_path_for(volunteer), alert: note.errors.full_messages.to_sentence
    end
  end

  def bulk_add_note
    volunteers = selected_volunteers
    note_content = params[:note].to_s
    list_path = bulk_return_path

    return redirect_to(list_path, alert: "Select at least one volunteer") if volunteers.empty?

    if note_content.blank?
      redirect_to list_path, alert: "Content can't be blank"
      return
    end

    if note_content.length > Note::MAX_CONTENT_LENGTH
      redirect_to list_path, alert: "Content is too long (maximum is #{Note::MAX_CONTENT_LENGTH} characters)"
      return
    end

    volunteers.each do |volunteer|
      volunteer.add_staff_note(content: note_content, user: current_user, note_type: :general)
    end

    redirect_to list_path, notice: "Note added to #{helpers.pluralize(volunteers.size, 'volunteer')}"
  end

  # Texts every selected volunteer who has a phone number; the rest are skipped and counted.
  def bulk_send_sms
    volunteers = selected_volunteers
    list_path = bulk_return_path
    return redirect_to(list_path, alert: "Select at least one volunteer") if volunteers.empty?

    textable, no_phone = volunteers.partition { |volunteer| volunteer.phone.present? }
    sent = failed = 0
    textable.each do |volunteer|
      Sms::MailchimpOutbound.deliver!(volunteer: volunteer, body: params[:message], sent_by_user: current_user)
      sent += 1
    rescue Sms::MailchimpOutbound::BlankMessageError, Sms::MailchimpOutbound::MessageTooLongError => e
      # Same message for everyone, so stop at the first one
      return redirect_to(list_path, alert: e.message)
    rescue Sms::MailchimpOutbound::Error
      failed += 1
    end

    summary = [ sent.zero? ? "No SMS sent." : "SMS sent to #{helpers.pluralize(sent, 'volunteer')}." ]
    summary << "Skipped #{no_phone.size} with no phone number." if no_phone.any?
    summary << "#{failed} couldn't be sent." if failed.positive?
    redirect_to list_path, (sent.zero? ? :alert : :notice) => summary.join(" ")
  end

  # Sends the application to selected volunteers who are still at inquiry or eligible and haven't
  # had one yet. Anyone else is skipped so a bulk send never moves someone back a step.
  def bulk_send_application
    volunteers = selected_volunteers
    list_path = bulk_return_path
    return redirect_to(list_path, alert: "Select at least one volunteer") if volunteers.empty?

    ready, skipped = volunteers.partition do |volunteer|
      volunteer.application_sent_at.nil? && (volunteer.inquiry? || volunteer.application_eligible?)
    end
    ready.each { |volunteer| volunteer.record_application_sent!(user: current_user) }

    summary = [ ready.empty? ? "No applications sent." : "Application sent to #{helpers.pluralize(ready.size, 'volunteer')}." ]
    summary << "Skipped #{skipped.size} who already had one, applied, or are inactive." if skipped.any?
    redirect_to list_path, (ready.empty? ? :alert : :notice) => summary.join(" ")
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

  # The note/SMS popup sends the page it was opened from, so staff land back on the
  # profile or the same filtered list
  def return_path_for(volunteer)
    url_from(params[:return_to]) || volunteer_path(volunteer)
  end

  def selected_volunteers
    Volunteer.where(id: Array(params[:volunteer_ids]).reject(&:blank?)).to_a
  end

  # Bulk actions go back to the same filtered list they were sent from
  def bulk_return_path
    url_from(params[:return_to]) || volunteers_path(list_filter_params)
  end

  # Search/filter values for the volunteers list. Unknown statuses and counties are
  # dropped so a stale or hand-edited URL shows the full list instead of nothing.
  def list_filter_params
    county_param = params[:county_id].to_s.presence
    county_id = county_param && NjCounty.where(id: county_param).pick(:id)

    {
      q: params[:q].to_s.strip.presence,
      status: params[:status].presence_in(Volunteer.current_funnel_stages.keys),
      county_id: county_id
    }.compact
  end

  def volunteer_params
    params.require(:volunteer).permit(:first_name, :last_name, :email, :phone, :nj_county_id, :referral_source_id)
  end
end
