module PossibleDuplicatesHelper
  MergeChoice = Data.define(:key, :label, :options, :selected_id, :note)

  # Lowest to highest, so the status choice starts on whichever record is further along
  MERGE_STAGE_ORDER = %w[inactive inquiry application_eligible application_sent applied].freeze

  # Choices for the Merge popup. Email and phone default to the newer record.
  def merge_choices(pair)
    older, newer = pair.volunteer, pair.other_volunteer
    further_along = MERGE_STAGE_ORDER.index(newer.current_funnel_stage) > MERGE_STAGE_ORDER.index(older.current_funnel_stage) ? newer : older

    [
      merge_choice("name", "Name", older, newer, default: older, &:full_name),
      merge_choice("email", "Email", older, newer, default: newer, &:email),
      merge_choice("phone", "Phone", older, newer, default: newer) { |volunteer| volunteer.phone.presence },
      merge_choice("status", "Status", older, newer, default: further_along) { |volunteer| merge_status_label(volunteer) }
    ]
  end

  def merge_choice(key, label, *volunteers, default:)
    present = volunteers.filter_map { |volunteer| (text = yield(volunteer)) && [ volunteer.id, text ] }
    options = present.uniq(&:last)
    note = merge_choice_note(present, options)
    options = [ [ volunteers.first.id, "No #{label.downcase}" ] ] if options.empty?
    selected_id = options.map(&:first).include?(default.id) ? default.id : options.first.first

    MergeChoice.new(key:, label:, options:, selected_id:, note:)
  end

  # Why a field shows one value instead of a choice
  def merge_choice_note(present, options)
    return "Neither record has one" if present.empty?
    return "Only one record has one" if present.one?

    "Same on both" if options.one?
  end

  def merge_status_label(volunteer)
    stage = volunteer.current_funnel_stage
    label = VolunteersHelper::STATUS_BADGE_LABELS.fetch(stage) { stage.humanize }
    return label unless volunteer.inactive? && volunteer.inactive_reason.present?

    "#{label} (#{volunteer.inactive_reason.humanize(capitalize: false)})"
  end
end
