# Pairs of volunteers with the same phone number or the same first and last name
class PossibleDuplicates
  Pair = Data.define(:volunteer, :other_volunteer, :reasons)

  REASON_LABELS = { "name" => "Same name", "phone" => "Same phone" }.freeze

  # A phone number with fewer digits than this is too incomplete to compare
  MIN_PHONE_DIGITS = 7

  # One row per match, so a pair with the same name and phone appears twice. Phones compare their
  # last 10 digits and names ignore case and extra spaces. Leaves out anyone already made inactive
  # as a Duplicate and pairs marked "Not a duplicate".
  UNRESOLVED_MATCHES = <<~'SQL'.squish.freeze
    WITH reviewable AS (
      SELECT id,
             RIGHT(REGEXP_REPLACE(COALESCE(phone, ''), '[^0-9]', '', 'g'), 10) AS phone_key,
             LOWER(REGEXP_REPLACE(BTRIM(first_name) || ' ' || BTRIM(last_name), '\s+', ' ', 'g')) AS name_key
      FROM volunteers
      WHERE NOT (current_funnel_stage = :inactive AND inactive_reason IS NOT DISTINCT FROM :duplicate)
    ), matches AS (
      SELECT a.id AS volunteer_id, b.id AS other_volunteer_id, 'phone' AS reason
      FROM reviewable a JOIN reviewable b ON b.id > a.id AND b.phone_key = a.phone_key
      WHERE LENGTH(a.phone_key) >= :min_phone_digits
      UNION ALL
      SELECT a.id, b.id, 'name'
      FROM reviewable a JOIN reviewable b ON b.id > a.id AND b.name_key = a.name_key
    ), unresolved AS (
      SELECT matches.* FROM matches
      WHERE NOT EXISTS (
        SELECT 1 FROM duplicate_dismissals d
        WHERE d.volunteer_id = matches.volunteer_id AND d.other_volunteer_id = matches.other_volunteer_id
      )
    )
  SQL

  # Newest pairs first, each with the older record first
  def self.pairs
    rows = ActiveRecord::Base.connection.select_rows(query(<<~'SQL'))
      SELECT volunteer_id, other_volunteer_id, STRING_AGG(DISTINCT reason, ',' ORDER BY reason)
      FROM unresolved
      GROUP BY volunteer_id, other_volunteer_id
    SQL
    volunteers = Volunteer.where(id: rows.flat_map { |row| row.first(2) }).index_by(&:id)

    rows.map do |volunteer_id, other_volunteer_id, reasons|
      people = [ volunteers.fetch(volunteer_id.to_i), volunteers.fetch(other_volunteer_id.to_i) ].sort_by(&:created_at)
      Pair.new(*people, reasons.split(",").map { |reason| REASON_LABELS.fetch(reason) })
    end.sort_by { |pair| -pair.other_volunteer.created_at.to_f }
  end

  def self.count
    ActiveRecord::Base.connection.select_value(query(<<~'SQL')).to_i
      SELECT COUNT(*) FROM (SELECT DISTINCT volunteer_id, other_volunteer_id FROM unresolved) pairs
    SQL
  end

  def self.any?
    ActiveRecord::Base.connection.select_value(query("SELECT EXISTS (SELECT 1 FROM unresolved)"))
  end

  # UNRESOLVED_MATCHES followed by a query on it, with the values bound
  def self.query(sql)
    ActiveRecord::Base.sanitize_sql_array([
      "#{UNRESOLVED_MATCHES} #{sql.squish}",
      { inactive: Volunteer.current_funnel_stages.fetch("inactive"),
        duplicate: Volunteer.inactive_reasons.fetch("duplicate"),
        min_phone_digits: MIN_PHONE_DIGITS }
    ])
  end
  private_class_method :query
end
