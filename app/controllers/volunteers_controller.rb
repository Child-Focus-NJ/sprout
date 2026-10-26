class VolunteersController < ApplicationController
  before_action :set_volunteer, only: [ :show, :update, :destroy, :update_status, :send_application, :mark_submitted, :sms, :sms_template, :send_sms ]

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

  def sms
  end

  def sms_template
    template = Sms::MailchimpOutbound.template!(params[:template_id])
    render json: { body: template.render_body(@volunteer) }
  rescue Sms::MailchimpOutbound::InvalidTemplateError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def send_sms
    communication = Sms::MailchimpOutbound.deliver!(
      volunteer: @volunteer,
      body: params[:message],
      sent_by_user: current_user,
      consent: params[:consent],
      template_id: params[:template_id]
    )
    notice = communication.queued? ? "SMS queued by Mailchimp" : "SMS sent to Mailchimp"
    redirect_to return_path_for(@volunteer), notice: notice
  rescue Sms::MailchimpOutbound::Error => e
    @message = params[:message].to_s
    @consent = params[:consent].to_s
    @template_id = params[:template_id].to_s
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

  # Texts every selected volunteer who has a phone number; the rest are skipped and named (a few of
  # them, plus a count) so staff know who didn't get it.
  def bulk_send_sms
    volunteers = selected_volunteers
    list_path = bulk_return_path
    return redirect_to(list_path, alert: "Select at least one volunteer") if volunteers.empty?

    no_phone = volunteers.where("COALESCE(TRIM(volunteers.phone), '') = ''")
    sent = queued = uncertain = failed = 0
    volunteers.where("COALESCE(TRIM(volunteers.phone), '') <> ''").find_each do |volunteer|
      communication = Sms::MailchimpOutbound.deliver!(
        volunteer: volunteer, body: params[:message], sent_by_user: current_user, consent: params[:consent],
        template_id: params[:template_id], personalize: true
      )
      communication.queued? ? queued += 1 : sent += 1
    rescue Sms::MailchimpOutbound::MessageTooLongError => e
      return redirect_to(list_path, alert: e.message) if params[:template_id].blank?

      failed += 1
    rescue Sms::MailchimpOutbound::BlankMessageError,
           Sms::MailchimpOutbound::MissingConsentError, Sms::MailchimpOutbound::ConfigurationError,
           Sms::MailchimpOutbound::InvalidTemplateError => e
      # Same message for everyone, so stop at the first one
      return redirect_to(list_path, alert: e.message)
    rescue Sms::MailchimpOutbound::UncertainDeliveryError
      uncertain += 1
    rescue Sms::MailchimpOutbound::Error
      failed += 1
    end

    summary = [ sent.zero? ? "No SMS sent." : "SMS sent to #{helpers.pluralize(sent, 'volunteer')}." ]
    summary << "SMS queued by Mailchimp for #{helpers.pluralize(queued, 'volunteer')}." if queued.positive?
    summary << "#{uncertain} SMS could not be confirmed. Check Mailchimp activity before resending." if uncertain.positive?
    skipped = no_phone.count
    summary << "Skipped #{skipped} with no phone number: #{some_names(no_phone, skipped)}." if skipped.positive?
    summary << "#{failed} couldn't be sent." if failed.positive?
    redirect_to list_path, (sent.zero? && queued.zero? ? :alert : :notice) => summary.join(" ")
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
    Volunteer.where(id: Array(params[:volunteer_ids]).reject(&:blank?))
  end

  # The first few names plus a count of the rest, so the message stays short (and fits in the
  # session cookie the flash lives in) no matter how many volunteers are in the list
  def some_names(scope, total, shown: 3)
    names = scope.order(:first_name, :last_name).limit(shown).pluck(:first_name, :last_name).map { |name| name.join(" ") }
    rest = total - names.size
    (rest.positive? ? names + [ "#{helpers.number_with_delimiter(rest)} more" ] : names).to_sentence
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
