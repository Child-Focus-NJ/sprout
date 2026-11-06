class ReplaceLegacyCountiesWithVicinages < ActiveRecord::Migration[8.1]
  VICINAGES = %w[Passaic Union Either Unknown].freeze

  def up
    VICINAGES.each { |name| Vicinage.find_or_create_by!(name: name) }
    unknown_id = Vicinage.find_by!(name: "Unknown").id

    # Legacy county data does not identify a volunteer's vicinage preference.
    Volunteer.where.not(vicinage_id: nil).update_all(vicinage_id: unknown_id)
    InquiryFormSubmission.where.not(vicinage_id: nil).update_all(vicinage_id: unknown_id)

    Vicinage.where.not(id: Vicinage.where(name: VICINAGES).select(:id)).delete_all
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
