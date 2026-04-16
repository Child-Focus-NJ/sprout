class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # Request specs and non-browser clients get 403 without this guard in test.
  allow_browser versions: :modern unless Rails.env.test?

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :require_authenticated_and_authorized_user!

  helper_method :current_user

  private

  def require_admin!
    return if current_user&.admin?

    redirect_to root_path, alert: "You are not authorized to view that page."
  end

  def require_authenticated_and_authorized_user!
    return if allow_unauthenticated_access?

    unless current_user.present?
      redirect_to login_path, alert: "Please sign in to continue."
      return
    end

    return if current_user.active?

    reset_session
    redirect_to login_path, alert: "Your account is inactive."
  end

  def allow_unauthenticated_access?
    (controller_name == "sessions" && %w[new create failure].include?(action_name)) ||
      request.path == "/up"
  end

  def deliver_application_queued_email!(volunteer)
    return if volunteer.email.blank?

    AttendanceMailer.application_queued(volunteer.email).deliver_now
  end

  def complete_info_session_check_in_success!(volunteer:, information_session:)
    volunteer.finalize_check_in_for_session!(information_session, user: current_user)
    deliver_application_queued_email!(volunteer)
    redirect_to volunteer_path(volunteer), notice: "Application queued for #{volunteer.full_name}"
  end

  def redirect_if_already_attended_for_session!(volunteer:, information_session:, registration: nil)
    registration ||= SessionRegistration.find_by(volunteer: volunteer, information_session: information_session)
    return false unless registration&.attended?

    redirect_to volunteer_path(volunteer), notice: "#{volunteer.full_name} is already checked in for this session."
    true
  end

  def current_user
    return @current_user if defined?(@current_user)
    # In the browser flow, we set `session[:user_id]` in `SessionsController`.
    # In Cucumber tests, `login_as(..., scope: :user)` sets Warden's current user.
    @current_user = request.env["warden"]&.user(:user) || User.find_by(id: session[:user_id])
  end
end
