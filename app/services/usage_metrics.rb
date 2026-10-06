# How much the system is being used, how much data it holds,
# and how much communication has gone out

class UsageMetrics
  def initialize(today: Date.current)
    @today = today
  end

  def total_sign_ins
    SignInLog.count
  end

  def sign_ins_this_month
    SignInLog.where(created_at: month_start..@today.end_of_day).count
  end

  def recent_sign_ins(limit: 10)
    SignInLog.recent.includes(:user).limit(limit)
  end

  def unique_sign_in_users
    SignInLog.distinct.count(:user_id)
  end

  def total_volunteers
    Volunteer.count
  end

  def total_information_sessions
    InformationSession.count
  end

  def total_notes
    Note.count
  end

  def total_communications
    communications_by_type.values.sum
  end

  def communications_by_type
    @communications_by_type ||= begin
      counts = Communication.group(:communication_type).count
      Communication.communication_types.keys.index_with { |type| counts.fetch(type, 0) }
    end
  end

  def recent_communications(limit: 10)
    Communication.recent.includes(:volunteer).limit(limit)
  end

  def total_active_employees
    employees_by_role.values.sum
  end

  def employees_by_role
    @employees_by_role ||= begin
      counts = User.active.group(:role).count
      User.roles.keys.index_with { |role| counts.fetch(role, 0) }
    end
  end

  private

  def month_start
    @today.beginning_of_month.beginning_of_day
  end
end
