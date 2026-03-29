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
    volunteer = Volunteer.find(params[:volunteer_id])

    registration = SessionRegistration.find_by!(
      volunteer: volunteer,
      information_session: @session
    )
    registration.update!(status: :attended, checked_in_at: Time.current)

    volunteer.update!(first_session_attended_at: Time.current) unless volunteer.first_session_attended_at.present?
    volunteer.change_status!(:application_sent, user: current_user, trigger: :event)
    volunteer.update!(application_sent_at: Time.current) unless volunteer.application_sent_at.present?

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
