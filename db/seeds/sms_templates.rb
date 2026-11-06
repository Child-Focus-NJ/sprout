# A manual starter for both individual and bulk SMS. Preserve staff edits and
# inactive choices when seeds run again; creating it never sends a message.
CommunicationTemplate.find_or_create_by!(name: "General SMS follow-up", template_type: :sms) do |template|
  template.body = "Hi {{first_name}}, we're following up about your interest in volunteering. Please reply with any questions or let us know a good time to reach you."
  template.funnel_stage = :inquiry
  template.trigger_type = :manual
  template.active = true
end
