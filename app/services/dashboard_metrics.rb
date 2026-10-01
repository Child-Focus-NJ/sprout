# frozen_string_literal: true

# Headline numbers for the dashboard, the rules live here so the Reporting
# page can reuse the same definitions later
class DashboardMetrics
  # Volunteers added through the inquiry form have no inquiry_date, so fall back to
  # when they were created
  INQUIRED_AT_SQL = "COALESCE(volunteers.inquiry_date, volunteers.created_at)"

  ATTENDANCE_WINDOW_DAYS = 90
  # Check-in is the only attendance the app records, so a registration still marked
  # registered after its session counts as a miss
  EXPECTED_REGISTRATION_STATUSES = %w[registered attended no_show].freeze

  # One step of the conversion funnel: share is out of everyone who inquired,
  # step_rate is out of the step before (nil for the first step)
  FunnelStep = Data.define(:key, :count, :share, :step_rate)

  Attendance = Data.define(:attended, :expected) do
    def rate
      expected.zero? ? nil : attended.fdiv(expected)
    end
  end

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
    Volunteer.group_by_month(Arel.sql(INQUIRED_AT_SQL), range: inquiry_window(months)).count
  end

  # Everyone who inquired in the same 12 months as the inquiries chart, counted at each
  # step they reached. A step counts if its date is set or the volunteer is at that stage
  # or a later one, so someone moved forward by hand still counts, and each step includes
  # the ones after it so the funnel never widens.
  def conversion_funnel
    @conversion_funnel ||= begin
      window = inquiry_window(12)
      cohort = Volunteer.where("#{INQUIRED_AT_SQL} BETWEEN ? AND ?", window.begin, window.end)
      applied = cohort.where.not(application_submitted_at: nil).or(cohort.where(current_funnel_stage: :applied))
      sent = applied.or(cohort.where.not(application_sent_at: nil)).or(cohort.where(current_funnel_stage: :application_sent))
      attended = sent.or(cohort.where.not(first_session_attended_at: nil))
                     .or(cohort.where(current_funnel_stage: :application_eligible))

      counts = { inquired: cohort.count, attended: attended.count, application_sent: sent.count, applied: applied.count }
      counts.each_with_index.map do |(key, count), index|
        previous = counts.values[index - 1] if index.positive?
        FunnelStep.new(key: key, count: count, share: rate(count, counts[:inquired]), step_rate: previous && rate(count, previous))
      end
    end
  end

  # Share of the past year's inquiries that have applied, or nil if nobody inquired.
  def conversion_rate
    conversion_funnel.last.share
  end

  def attendance_window_start
    (@today - ATTENDANCE_WINDOW_DAYS).beginning_of_day
  end

  # Registrations for sessions held in the past 90 days, and how many of those checked in
  def session_attendance
    @session_attendance ||= begin
      counts = past_registrations.group(:status).count
      Attendance.new(attended: counts.fetch("attended", 0), expected: counts.values.sum)
    end
  end

  # The most recent sessions in the same window, newest first, each with its own attendance
  def recent_session_attendance(limit: 5)
    sessions = InformationSession.where(scheduled_at: attendance_window_start..Time.current)
                                 .order(scheduled_at: :desc).limit(limit).to_a
    counts = past_registrations.where(information_session: sessions).group(:information_session_id, :status).count

    sessions.map do |session|
      expected = EXPECTED_REGISTRATION_STATUSES.sum { |status| counts.fetch([ session.id, status ], 0) }
      [ session, Attendance.new(attended: counts.fetch([ session.id, "attended" ], 0), expected: expected) ]
    end
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

  private

  def inquiry_window(months)
    (month_start - (months - 1).months).beginning_of_day..@today.end_of_day
  end

  def past_registrations
    SessionRegistration.joins(:information_session)
                       .where(information_sessions: { scheduled_at: attendance_window_start..Time.current })
                       .where(status: EXPECTED_REGISTRATION_STATUSES)
  end

  def rate(part, whole)
    whole.zero? ? nil : part.fdiv(whole)
  end
end
