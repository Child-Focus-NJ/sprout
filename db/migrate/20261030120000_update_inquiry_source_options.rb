class UpdateInquirySourceOptions < ActiveRecord::Migration[8.1]
  INQUIRY_SOURCES = [ "Tabling Event", "Church Presentation", "Idealist", "Website", "Word of Mouth", "Other" ].freeze
  RETIRED_SOURCES = [ "Facebook", "Instagram", "Flyer", "School" ].freeze

  def up
    INQUIRY_SOURCES.each do |name|
      execute <<~SQL
        INSERT INTO referral_sources (name, active, created_at, updated_at)
        VALUES (#{connection.quote(name)}, true, NOW(), NOW())
        ON CONFLICT (name) DO UPDATE SET active = true, updated_at = NOW()
      SQL
    end
    execute "UPDATE referral_sources SET active = false, updated_at = NOW() WHERE name IN (#{quoted(RETIRED_SOURCES)})"
  end

  def down
    execute "UPDATE referral_sources SET active = true, updated_at = NOW() WHERE name IN (#{quoted(RETIRED_SOURCES)})"
  end

  private

  def quoted(names)
    names.map { |name| connection.quote(name) }.join(", ")
  end
end
