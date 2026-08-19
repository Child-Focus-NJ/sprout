class SeedNjCountiesAndReferralSources < ActiveRecord::Migration[8.1]
  COUNTIES = [
    "Atlantic", "Bergen", "Burlington", "Camden", "Cape May", "Cumberland", "Essex", "Gloucester",
    "Hudson", "Hunterdon", "Mercer", "Middlesex", "Monmouth", "Morris", "Ocean", "Passaic", "Salem",
    "Somerset", "Sussex", "Union", "Warren"
  ].freeze

  REFERRAL_SOURCES = [
    "Facebook", "Instagram", "Word of Mouth", "Website", "Flyer", "School", "Other"
  ].freeze

  # Data migration: seeds fixed lookup values that the app depends on to run
  # (county/referral-source dropdowns). Runs via db:migrate in every
  # environment, unlike db/seeds.rb which is dev/demo-data only and has to be
  # invoked manually. Uses the actual models (rather than raw SQL) since
  # NjCounty currently has no DB-level unique constraint on `name` — see the
  # companion migration adding that index.
  def up
    COUNTIES.each { |name| NjCounty.find_or_create_by!(name: name) }
    REFERRAL_SOURCES.each { |name| ReferralSource.find_or_create_by!(name: name) { |r| r.active = true } }
  end

  def down
    # Intentionally a no-op: this is reference data, not schema. Rolling back
    # the migration that created it shouldn't delete counties/sources that
    # may already be referenced by volunteers or inquiry_form_submissions.
  end
end
