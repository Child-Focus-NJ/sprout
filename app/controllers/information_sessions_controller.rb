class InformationSessionsController < ApplicationController
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
    volunteer.change_status!(:application_eligible, user: current_user, trigger: :event)

    redirect_to volunteer_path(volunteer)
  end
end
