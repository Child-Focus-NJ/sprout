# frozen_string_literal: true

# Headline numbers for the dashboard, the rules live here so the Reporting
# page can reuse the same definitions later
class DashboardMetrics
  # Volunteers added through the inquiry form have no inquiry_date, so fall back to
  # when they were created
  INQUIRED_AT_SQL = "COALESCE(volunteers.inquiry_date, volunteers.created_at)"

  def initialize(today: Date.current)
    @today = today
  end

  def total_volunteers
    Volunteer.count
  end

  def inactive_volunteers
    Volunteer.inactive_volunteers.count
  end

  def active_volunteers
    total_volunteers - inactive_volunteers
  end

  # Every funnel stage in order with its count, including stages nobody is in yet
  def volunteers_by_stage
    counts = Volunteer.group(:current_funnel_stage).count
    Volunteer.current_funnel_stages.keys.index_with { |stage| counts.fetch(stage, 0) }
  end

  def month_start
    @today.beginning_of_month
  end

  def new_inquiries_this_month
    inquiries_by_month(months: 1).values.sum
  end

  def inquiries_by_month(months: 12)
    range = (month_start - (months - 1).months).beginning_of_day..@today.end_of_day
    Volunteer.group_by_month(Arel.sql(INQUIRED_AT_SQL), range: range).count
  end

  def awaiting_submission_count
    Volunteer.awaiting_application_submission.count
  end

  # Days the longest-waiting volunteer has had their application, or nil if nobody is waiting.
  def longest_submission_wait_days
    oldest_sent_at = Volunteer.awaiting_application_submission.minimum(:application_sent_at)
    return nil if oldest_sent_at.nil?

    (@today - oldest_sent_at.to_date).to_i
  end

  def upcoming_sessions_count
    InformationSession.upcoming.count
  end

  def next_session
    InformationSession.upcoming.first
  end
end
