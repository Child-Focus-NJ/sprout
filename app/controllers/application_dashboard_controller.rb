class ApplicationDashboardController < ApplicationController
  # The New inquiries column shows this many cards. Its count still covers all of them.
  NEW_INQUIRIES_SHOWN = 15

  def index
    @metrics = DashboardMetrics.new
    @awaiting_submission = Volunteer.awaiting_application_submission
    new_inquiries = current_user.new_inquiries
    @new_inquiries = new_inquiries.includes(:referral_source).limit(NEW_INQUIRIES_SHOWN).to_a
    @new_inquiry_count = @new_inquiries.size < NEW_INQUIRIES_SHOWN ? @new_inquiries.size : new_inquiries.count
  end

  # The × on a card in the New inquiries column hides that volunteer for this staff member only
  def dismiss_new_inquiry
    volunteer = Volunteer.find_by(id: params[:volunteer_id])
    InquiryDismissal.dismiss!(current_user, volunteer) if volunteer
    redirect_to application_dashboard_path, status: :see_other
  end

  # Clear all empties the column for this staff member by starting their notices from now, so
  # anyone who inquires or comes back afterwards still shows
  def clear_new_inquiries
    current_user.touch(:inquiry_notices_since)
    redirect_to application_dashboard_path, status: :see_other
  end
end
