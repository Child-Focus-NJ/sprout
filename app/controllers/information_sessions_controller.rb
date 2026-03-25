class InformationSessionsController < ApplicationController
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
end
