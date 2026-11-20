# Pairs of volunteers with the same phone number or the same first and last name
class PossibleDuplicates
  Pair = Data.define(:volunteer, :other_volunteer, :reasons)

  REASON_LABELS = { "name" => "Same name", "phone" => "Same phone" }.freeze

  # A phone number with fewer digits than this is too incomplete to compare
  MIN_PHONE_DIGITS = 7

  # Each check compares one normalized value per volunteer. %{v} is the table alias.
  MATCH_KEYS = {
    "phone" => "RIGHT(REGEXP_REPLACE(COALESCE(%{v}.phone, ''), '[^0-9]', '', 'g'), 10)",
    "name" => "LOWER(REGEXP_REPLACE(BTRIM(%{v}.first_name) || ' ' || BTRIM(%{v}.last_name), '[[:space:]]+', ' ', 'g'))"
  }.freeze

  # Newest pairs first, each with the older record first
  def self.pairs
    rows = ActiveRecord::Base.connection.select_rows(<<~SQL.squish)
      SELECT volunteer_id, other_volunteer_id, STRING_AGG(DISTINCT reason, ',' ORDER BY reason)
      FROM (#{unresolved_matches_sql}) matches
      GROUP BY volunteer_id, other_volunteer_id
    SQL
    volunteers = Volunteer.where(id: rows.flat_map { |row| row.first(2) }).index_by(&:id)

    rows.map do |volunteer_id, other_volunteer_id, reasons|
      people = [ volunteers.fetch(volunteer_id.to_i), volunteers.fetch(other_volunteer_id.to_i) ].sort_by(&:created_at)
      Pair.new(*people, reasons.split(",").map { |reason| REASON_LABELS.fetch(reason) })
    end.sort_by { |pair| -pair.other_volunteer.created_at.to_f }
  end

  def self.count
    ActiveRecord::Base.connection.select_value(<<~SQL.squish).to_i
      SELECT COUNT(*) FROM (SELECT DISTINCT volunteer_id, other_volunteer_id FROM (#{unresolved_matches_sql}) matches) pairs
    SQL
  end

  def self.any?
    ActiveRecord::Base.connection.select_value("SELECT EXISTS (#{unresolved_matches_sql})")
  end

  # One row per matching check, so a pair with the same name and phone appears twice
  def self.unresolved_matches_sql
    MATCH_KEYS.map do |reason, key|
      a_key = format(key, v: "a")
      b_key = format(key, v: "b")
      minimum = reason == "phone" ? "AND LENGTH(#{a_key}) >= #{MIN_PHONE_DIGITS}" : ""
      <<~SQL
        SELECT a.id AS volunteer_id, b.id AS other_volunteer_id, '#{reason}' AS reason
        FROM (#{reviewable_volunteers_sql}) a
        JOIN (#{reviewable_volunteers_sql}) b ON b.id > a.id AND #{b_key} = #{a_key} #{minimum}
        WHERE NOT EXISTS (
          SELECT 1 FROM duplicate_dismissals d WHERE d.volunteer_id = a.id AND d.other_volunteer_id = b.id
        )
      SQL
    end.join(" UNION ALL ")
  end

  # Anyone already made inactive as a Duplicate has been dealt with
  def self.reviewable_volunteers_sql
    Volunteer.where.not(id: Volunteer.inactive.inactive_reason_duplicate.select(:id))
             .select(:id, :first_name, :last_name, :phone).to_sql
  end
  private_class_method :unresolved_matches_sql, :reviewable_volunteers_sql
end
