class InquiryFormController < ApplicationController
  def index
    redirect_to new_inquiry_form_path
  end

  def new
    @information_session_id = params[:information_session_id]
  end

  def create
    session_id = params[:information_session_id].presence
    email = params[:email].to_s.strip.downcase

    if session_id.present?
      info_session = InformationSession.find_by(id: session_id)
      unless info_session
        redirect_to new_inquiry_form_path, alert: "Invalid session."
        return
      end

      first_name = params[:first_name].to_s.strip
      last_name = params[:last_name].to_s.strip

      if email.blank? || first_name.blank? || last_name.blank?
        redirect_to new_inquiry_form_path(
          information_session_id: session_id,
          email: email,
          first_name: first_name,
          last_name: last_name
        ), alert: "First name, last name, and email are required."
        return
      end

      volunteer = Volunteer.find_by(email: email)

      if volunteer
        registration = SessionRegistration.find_by(volunteer: volunteer, information_session: info_session)
        if registration&.attended?
          redirect_to volunteer_path(volunteer), notice: "#{volunteer.full_name} is already checked in for this session."
          return
        end

        volunteer.finalize_check_in_for_session!(info_session, user: current_user)
        deliver_application_queued_email!(volunteer)

        redirect_to volunteer_path(volunteer), notice: "Application queued for #{volunteer.full_name}"
        return
      end

      volunteer = Volunteer.create!(
        first_name: first_name,
        last_name: last_name,
        email: email,
        current_funnel_stage: :inquiry
      )

      InquiryFormSubmission.create!(
        volunteer: volunteer,
        preferred_session: info_session,
        first_name: first_name,
        last_name: last_name,
        email: email,
        source: "walk_in_check_in",
        raw_data: {
          information_session_id: info_session.id,
          first_name: first_name,
          last_name: last_name,
          email: email
        },
        processed: true,
        processed_at: Time.current
      )

      volunteer.finalize_check_in_for_session!(info_session, user: current_user)
      deliver_application_queued_email!(volunteer)

      redirect_to volunteer_path(volunteer), notice: "Application queued for #{volunteer.full_name}"
      return
    end

    if email.blank?
      redirect_to new_inquiry_form_path, alert: "Email can't be blank."
      return
    end

    InquiryFormSubmission.create!(
      source: "public_inquiry_form",
      raw_data: {
        email: email
      },
      processed: false
    )

    redirect_to new_inquiry_form_path, notice: "Thanks! Your inquiry has been submitted."
  end
end
