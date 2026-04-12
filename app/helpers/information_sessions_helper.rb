module InformationSessionsHelper
  FILTER_PARAM_KEYS = %i[start_date end_date location upcoming_past page].freeze

  def information_sessions_filter_params
    params.permit(*FILTER_PARAM_KEYS).to_h.symbolize_keys
  end

  def information_sessions_path_with_filters(**extra)
    information_sessions_path(**information_sessions_filter_params.compact_blank.merge(extra))
  end

  def information_session_location_select_options(session)
    choices = InformationSession::LOCATION_CHOICES.map { |l| [l, l] }
    if session.location.present? && InformationSession::LOCATION_CHOICES.exclude?(session.location)
      choices.unshift([session.location, session.location])
    end
    choices
  end

  def information_session_creator_line(session)
    user = session.created_by_user
    if user
      "Created by: #{user.display_name} (#{user.email})"
    else
      "Created by: Unknown"
    end
  end
end
