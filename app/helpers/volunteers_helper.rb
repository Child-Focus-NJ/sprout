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

  # Heading for a profile timeline entry (e.g. :sms -> "SMS", :status_change -> "Status change").
  def timeline_entry_label(kind)
    kind == :sms ? "SMS" : kind.to_s.humanize
  end

  MESSAGE_DIALOG_LABELS = { note: "Add Note", sms: "Send SMS" }.freeze

  # Icons from Heroicons (https://heroicons.com, by Tailwind Labs, MIT license), 24px outline set:
  # "pencil-square" for notes and "device-phone-mobile" for SMS. Same set as the list's search and filter icons.
  MESSAGE_ICON_PATHS = {
    note: "m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L10.582 16.07a4.5 4.5 0 0 1-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 0 1 1.13-1.897l8.932-8.931Zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0 1 15.75 21H5.25A2.25 2.25 0 0 1 3 18.75V8.25A2.25 2.25 0 0 1 5.25 6H10",
    sms: "M10.5 1.5H8.25A2.25 2.25 0 0 0 6 3.75v16.5a2.25 2.25 0 0 0 2.25 2.25h7.5A2.25 2.25 0 0 0 18 20.25V3.75a2.25 2.25 0 0 0-2.25-2.25H13.5m-3 0V3h3V1.5m-3 0h3m-3 18.75h3"
  }.freeze

  def message_icon(tab)
    tag.svg(class: "message-icon", viewBox: "0 0 24 24", fill: "none", stroke: "currentColor",
            stroke_width: "1.5", aria: { hidden: true }) do
      tag.path(stroke_linecap: "round", stroke_linejoin: "round", d: MESSAGE_ICON_PATHS.fetch(tab))
    end
  end

  # An icon button that opens the note/SMS popup for this volunteer on the given tab.
  # The tooltip and screen reader label carry the words since the button only shows an icon.
  def message_dialog_button(volunteer, tab, css_class: "button-link")
    no_phone = volunteer.phone.blank?
    disabled = tab == :sms && no_phone
    label = MESSAGE_DIALOG_LABELS.fetch(tab)
    label = "#{label} (no phone number on file)" if disabled

    tag.button(
      message_icon(tab),
      type: "button",
      class: "#{css_class} icon-button",
      disabled: disabled,
      title: label,
      aria: { label: label },
      data: {
        message_dialog_open: tab,
        volunteer_name: volunteer.full_name,
        note_url: add_note_volunteer_path(volunteer),
        sms_url: send_sms_volunteer_path(volunteer),
        has_phone: !no_phone
      }
    )
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
