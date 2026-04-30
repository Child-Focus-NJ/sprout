class InformationSessionsController < ApplicationController
  SESSIONS_PER_PAGE = 10

  before_action :set_information_sessions_list_filters,
    only: [ :index, :new, :create, :edit, :sign_in, :update, :destroy, :remove_attendee ]

  def index
    rel = InformationSession.includes(:created_by_user).all

    if params[:start_date].present?
      start_date = parsed_list_filter_date(params[:start_date])
      rel = rel.where("scheduled_at >= ?", start_date.beginning_of_day) if start_date
    end

    if params[:end_date].present?
      end_date = parsed_list_filter_date(params[:end_date])
      rel = rel.where("scheduled_at <= ?", end_date.end_of_day) if end_date
    end

    if params[:location].present?
      rel = rel.where(location: params[:location])
    end

    time_filter = params[:upcoming_past].presence || "All"

    case time_filter
    when "Past"
      rel = rel.where("scheduled_at < ?", Time.current)
    when "Upcoming"
      rel = rel.where("scheduled_at >= ?", Time.current)
    end

    rel = rel.order(created_at: :desc)

    total = rel.count
    max_page = [ (total.to_f / SESSIONS_PER_PAGE).ceil, 1 ].max
    page = [ params[:page].to_i, 1 ].max
    page = [ page, max_page ].min

    @information_sessions = rel.offset((page - 1) * SESSIONS_PER_PAGE).limit(SESSIONS_PER_PAGE)
    @sessions_page = page
    @sessions_total_pages = max_page
    @sessions_total_count = total
  end

  def new
    @information_session = InformationSession.new
  end

  def create
    @information_session = InformationSession.new(information_session_params)
    @information_session.created_by_user = current_user
    if @information_session.save
      redirect_to information_sessions_path(**list_filter_params_compact.except(:page)),
        notice: "Information session was successfully created."
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
      redirect_to edit_information_session_path(@information_session, **list_filter_params_compact)
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

    if params[:volunteer_id].present?
      volunteer = Volunteer.find(params[:volunteer_id])

      SessionRegistration.find_by!(
        volunteer: volunteer,
        information_session: @session
      )

      complete_info_session_check_in_success!(volunteer: volunteer, information_session: @session)
      return
    end

    email = params[:email].to_s.strip.downcase
    volunteer = Volunteer.find_by(email: email)

    registration =
      if volunteer
        SessionRegistration.find_by(volunteer: volunteer, information_session: @session)
      end

    if redirect_if_already_attended_for_session!(
      volunteer: volunteer,
      information_session: @session,
      registration: registration
    )
      return
    end

    if volunteer.nil? || registration.nil? || !registration.registered?
      redirect_to new_inquiry_form_path(
        information_session_id: @session.id,
        email: email
      ), alert: "Please add them to the system (inquiry)."
      return
    end

    complete_info_session_check_in_success!(volunteer: volunteer, information_session: @session)
  end

  def remove_attendee
    session = InformationSession.find(params[:id])
    volunteer = Volunteer.find(params[:volunteer_id])
    registration = SessionRegistration.find_by!(information_session: session, volunteer: volunteer)
    registration.destroy

    redirect_to edit_information_session_path(session, **list_filter_params_compact), notice: "#{volunteer.full_name} removed!"
  end

  def destroy
    @information_session = InformationSession.find(params[:id])
    @information_session.destroy
    redirect_to information_sessions_path(**list_filter_params_compact), notice: "Information session was successfully deleted."
  end

  private

  def set_information_sessions_list_filters
    @list_filter_params = params.permit(:start_date, :end_date, :location, :upcoming_past, :page).to_h.symbolize_keys
  end

  def list_filter_params_compact
    params.permit(:start_date, :end_date, :location, :upcoming_past, :page).to_h.symbolize_keys.compact_blank
  end

  def parsed_list_filter_date(raw)
    return nil if raw.blank?

    Date.strptime(raw, "%m/%d/%y") rescue Date.parse(raw)
  end

  def information_session_params
    p = params.require(:information_session).permit(
      :name,
      :scheduled_at,
      :location,
      :capacity,
      :zoom_link
    )
    if p[:scheduled_at].present?
      p[:scheduled_at] = Time.zone.parse(p[:scheduled_at])
    end

    p
  end
end
