module InformationSessionsHelper
  FILTER_PARAM_KEYS = %i[start_date end_date location upcoming_past tab page].freeze

  def information_sessions_filter_params
    params.permit(*FILTER_PARAM_KEYS).to_h.symbolize_keys
  end

  def information_sessions_path_with_filters(**extra)
    information_sessions_path(**information_sessions_filter_params.compact_blank.merge(extra))
  end

  def information_sessions_tab_path(tab)
    filters = information_sessions_filter_params.except(:tab, :upcoming_past, :page).compact_blank
    information_sessions_path(filters.merge(tab: tab))
  end

  def information_session_tab_link(label, tab)
    active = @session_tab == tab
    classes = active ? "sys-tabs__link sys-tabs__link--active" : "sys-tabs__link"
    link_to label, information_sessions_tab_path(tab), class: classes, aria: { current: ("page" if active) }
  end

  def information_session_location_select_options(session)
    choices = InformationSession::LOCATION_CHOICES.map { |l| [ l, l ] }
    if session.location.present? && InformationSession::LOCATION_CHOICES.exclude?(session.location)
      choices.unshift([ session.location, session.location ])
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
