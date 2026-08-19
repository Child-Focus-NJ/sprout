class AddCountyAndReferralSourceReferences < ActiveRecord::Migration[8.1]
  def up
    add_reference :volunteers, :nj_county, foreign_key: true
    add_reference :inquiry_form_submissions, :nj_county, foreign_key: true
    add_reference :inquiry_form_submissions, :referral_source, foreign_key: true

    # --- Data backfill -----------------------------------------------------
    # `volunteers.referral_source_id` already exists but was never populated
    # from the old `how_did_you_hear` string. Before dropping the string
    # columns below, map existing string values onto the lookup tables so no
    # data is lost.
    #
    # NOTE: `volunteers.county` / `volunteers.how_did_you_hear` were never
    # actually created by a migration — they only ever existed because an
    # earlier schema.rb was dumped from a database that had them added by
    # hand. On a database built by replaying every migration from scratch
    # (rather than db:schema:load), those columns genuinely don't exist, so
    # everything touching them here is guarded with column_exists?.
    say_with_time "Backfilling nj_county_id / referral_source_id from strings" do
      if column_exists?(:volunteers, :county)
        execute <<~SQL
          UPDATE volunteers v
          SET nj_county_id = c.id
          FROM nj_counties c
          WHERE v.county IS NOT NULL AND lower(trim(v.county)) = lower(trim(c.name))
        SQL
      end

      if column_exists?(:volunteers, :how_did_you_hear)
        execute <<~SQL
          UPDATE volunteers v
          SET referral_source_id = r.id
          FROM referral_sources r
          WHERE v.referral_source_id IS NULL
            AND v.how_did_you_hear IS NOT NULL
            AND lower(trim(v.how_did_you_hear)) = lower(trim(r.name))
        SQL
      end

      execute <<~SQL
        UPDATE inquiry_form_submissions s
        SET nj_county_id = c.id
        FROM nj_counties c
        WHERE s.county IS NOT NULL AND lower(trim(s.county)) = lower(trim(c.name))
      SQL

      execute <<~SQL
        UPDATE inquiry_form_submissions s
        SET referral_source_id = r.id
        FROM referral_sources r
        WHERE s.how_did_you_hear IS NOT NULL
          AND lower(trim(s.how_did_you_hear)) = lower(trim(r.name))
      SQL
    end

    remove_column :volunteers, :county, :string if column_exists?(:volunteers, :county)
    remove_column :volunteers, :how_did_you_hear, :string if column_exists?(:volunteers, :how_did_you_hear)
    remove_column :inquiry_form_submissions, :county, :string
    remove_column :inquiry_form_submissions, :how_did_you_hear, :string
  end

  def down
    add_column :volunteers, :county, :string unless column_exists?(:volunteers, :county)
    add_column :volunteers, :how_did_you_hear, :string unless column_exists?(:volunteers, :how_did_you_hear)
    add_column :inquiry_form_submissions, :county, :string
    add_column :inquiry_form_submissions, :how_did_you_hear, :string

    remove_reference :inquiry_form_submissions, :referral_source, foreign_key: true
    remove_reference :inquiry_form_submissions, :nj_county, foreign_key: true
    remove_reference :volunteers, :nj_county, foreign_key: true
  end
end
