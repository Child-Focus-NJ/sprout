class InformationSessionsController < ApplicationController
  def index
    @information_sessions = InformationSession.all

    if params[:start_date].present?
      start_date = Date.strptime(params[:start_date], "%m/%d/%y") rescue Date.parse(params[:start_date])
      @information_sessions = @information_sessions.where("scheduled_at >= ?", start_date.beginning_of_day)
    end

    if params[:end_date].present?
      end_date = Date.strptime(params[:end_date], "%m/%d/%y") rescue Date.parse(params[:end_date])
      @information_sessions = @information_sessions.where("scheduled_at <= ?", end_date.end_of_day)
    end

    if params[:location].present?
      @information_sessions = @information_sessions.where(location: params[:location])
    end

    if params[:upcoming_past] == "Past"
      @information_sessions = @information_sessions.where("scheduled_at < ?", Time.current)
    elsif params[:upcoming_past] == "Upcoming" || params[:upcoming_past].blank?
      @information_sessions = @information_sessions.where("scheduled_at >= ?", Time.current)
    end
  end

  def new
    @information_session = InformationSession.new
  end

def create
  @information_session = InformationSession.new(information_session_params)

  if @information_session.save
    redirect_to information_sessions_path, notice: "Information session was successfully created."
  else
    flash.now[:alert] = "Please fix the errors below."
    render :new
  end
end

  def edit
    @information_session = InformationSession.find(params[:id])
  end

  def update
    @information_session = InformationSession.find(params[:id])

    if @information_session.update(information_session_params)
      redirect_to edit_information_session_path(@information_session)
    else
      flash.now[:alert] = "Please fix the errors below."
      render :edit
    end
  end

  def sign_in
    @session = InformationSession.find(params[:id])
  end

  def check_in
    @session = InformationSession.find(params[:id])

    # Registered volunteers submit with `volunteer_id`.
    if params[:volunteer_id].present?
      volunteer = Volunteer.find(params[:volunteer_id])

      SessionRegistration.find_by!(
        volunteer: volunteer,
        information_session: @session
      )

      volunteer.finalize_check_in_for_session!(@session, user: current_user)
      deliver_application_queued_email!(volunteer)

      redirect_to volunteer_path(volunteer), notice: "Application queued for #{volunteer.full_name}"
      return
    end

    # Walk-in volunteers submit with `email`.
    email = params[:email].to_s.strip.downcase
    volunteer = Volunteer.find_by(email: email)

    registration = volunteer && SessionRegistration.find_by(
      volunteer: volunteer,
      information_session: @session
    )

    if registration&.attended?
      redirect_to volunteer_path(volunteer), notice: "#{volunteer.full_name} is already checked in for this session."
      return
    end

    # Not on the session list (or not registered for this session): inquiry at check-in per meeting notes.
    if volunteer.nil? || registration.nil? || !registration.registered?
      redirect_to new_inquiry_form_path(
        information_session_id: @session.id,
        email: email
      ), alert: "Please add them to the system (inquiry)."
      return
    end

    volunteer.finalize_check_in_for_session!(@session, user: current_user)
    deliver_application_queued_email!(volunteer)

    redirect_to volunteer_path(volunteer), notice: "Application queued for #{volunteer.full_name}"
  end

  def remove_attendee
    session = InformationSession.find(params[:id])
    volunteer = Volunteer.find(params[:volunteer_id])
    registration = SessionRegistration.find_by!(information_session: session, volunteer: volunteer)
    registration.destroy

    redirect_to edit_information_session_path(session), notice: "#{volunteer.full_name} removed!"
  end

  def destroy
    @information_session = InformationSession.find(params[:id])
    @information_session.destroy
    redirect_to information_sessions_path, notice: "Information session was successfully deleted."
  end

  private

  def information_session_params
    p = params.require(:information_session).permit(
      :name,
      :scheduled_at,
      :location
    )
    if p[:scheduled_at].present?
        p[:scheduled_at] = Time.zone.parse(p[:scheduled_at])
    end

    p
  end
end
