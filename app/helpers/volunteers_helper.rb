module VolunteersHelper
  STATUS_BADGE_LABELS = {
    "inquiry" => "Inquiry",
    "application_eligible" => "Application eligible",
    "application_sent" => "Application sent",
    "applied" => "Applied",
    "inactive" => "Inactive"
  }.freeze

  # [label, value] pairs for status dropdowns, worded the same as the badges.
  def volunteer_status_options
    Volunteer.current_funnel_stages.keys.map do |stage|
      [ STATUS_BADGE_LABELS.fetch(stage) { stage.humanize }, stage ]
    end
  end

  # Color modifier for a stage, e.g. "status-badge--application-sent".
  def volunteer_status_color_class(stage)
    "status-badge--#{stage.to_s.tr('_', '-')}"
  end

  def volunteer_status_badge(volunteer)
    stage = volunteer.current_funnel_stage.to_s
    label = STATUS_BADGE_LABELS.fetch(stage) { stage.humanize }

    tag.span(
      label,
      class: "status-badge #{volunteer_status_color_class(stage)}",
      title: "Status: #{label}"
    )
  end
end
