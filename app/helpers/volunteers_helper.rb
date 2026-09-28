module VolunteersHelper
  STATUS_BADGE_LABELS = {
    "inquiry" => "Inquiry",
    "application_eligible" => "Application eligible",
    "application_sent" => "Application sent",
    "applied" => "Applied",
    "inactive" => "Inactive"
  }.freeze

  # Heading for a profile timeline entry (e.g. :sms -> "SMS", :status_change -> "Status change").
  def timeline_entry_label(kind)
    kind == :sms ? "SMS" : kind.to_s.humanize
  end

  def volunteer_status_badge(volunteer)
    stage = volunteer.current_funnel_stage.to_s
    label = STATUS_BADGE_LABELS.fetch(stage) { stage.humanize }

    tag.span(
      label,
      class: "status-badge status-badge--#{stage.tr('_', '-')}",
      title: "Status: #{label}"
    )
  end
end
