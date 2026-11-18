class ApplicationDashboardController < ApplicationController
  def index
    @metrics = DashboardMetrics.new
    @awaiting_submission = Volunteer.awaiting_application_submission
    @new_inquiries = current_user.new_inquiries.includes(:referral_source).to_a
  end

  # The × on a card in the New inquiries column hides that volunteer for this staff member only
  def dismiss_new_inquiry
    volunteer = Volunteer.find_by(id: params[:volunteer_id])
    current_user.inquiry_dismissals.create_or_find_by!(volunteer: volunteer) if volunteer
    redirect_to application_dashboard_path, status: :see_other
  end
end
