class InformationSessionsController < ApplicationController
  def index
    @information_sessions = InformationSession.all
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

  private

  def information_session_params
    params.require(:information_session).permit(
      :name,
      :scheduled_at,
      :location
    )
  end
end

