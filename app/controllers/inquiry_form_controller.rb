class InquiryFormController < ApplicationController
  def index
    redirect_to new_inquiry_form_path
  end

  def new
    @information_session_id = params[:information_session_id]
    @form_values = form_values_from_params
    @form_errors = {}
  end

  def create
    @information_session_id = params[:information_session_id].presence
    @form_values = form_values_from_params
    @form_errors = validate_form(@form_values)

    if @form_errors.any?
      render :new, status: :unprocessable_entity
      return
    end

    session_id = @information_session_id
    email = @form_values[:email]
    first_name = @form_values[:first_name]
    last_name = @form_values[:last_name]
    phone = @form_values[:phone]

    if session_id.present?
      info_session = InformationSession.find_by(id: session_id)
      unless info_session
        @form_errors[:base] = "Invalid session."
        render :new, status: :unprocessable_entity
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
        phone: phone,
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
          email: email,
          phone: phone
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

    if Volunteer.exists?(email: email)
      redirect_to new_inquiry_form_path, alert: "You've already signed up."
      return
    end

    InquiryFormSubmission.create!(
      source: "public_inquiry_form",
      raw_data: {
        first_name: first_name,
        last_name: last_name,
        email: email,
        phone: phone
      },
      processed: false
    )
    InquiryMailer.confirmation(email).deliver_now

    redirect_to new_inquiry_form_path, notice: "Thanks! Your inquiry has been submitted."
  end

  private

  def form_values_from_params
    {
      first_name: params[:first_name].to_s.strip,
      last_name: params[:last_name].to_s.strip,
      email: params[:email].to_s.strip.downcase,
      phone: params[:phone].to_s.strip
    }
  end

  def validate_form(values)
    errors = {}

    errors[:first_name] = "First name is required." if values[:first_name].blank?
    errors[:last_name] = "Last name is required." if values[:last_name].blank?
    errors[:email] = "Email is required." if values[:email].blank?
    if values[:email].present? && values[:email] !~ URI::MailTo::EMAIL_REGEXP
      errors[:email] = "Enter a valid email address."
    end

    digits = values[:phone].gsub(/\D/, "")
    errors[:phone] = "Phone number is required." if values[:phone].blank?
    if values[:phone].present? && digits.length != 10
      errors[:phone] = "Enter a valid 10-digit phone number."
    end

    errors
  end
end
