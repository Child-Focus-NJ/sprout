class SeedFeatures < ActiveRecord::Migration[8.1]
  FEATURES = {
    "system_management" => "Admin tab: reminder frequencies, volunteer tags, employees, referral sources",
    "users" => "Adding, editing, and deactivating employees",
    "reminder_frequencies" => "Managing reminder frequency options",
    "volunteer_tags" => "Managing volunteer tag options",
    "referral_sources" => "Managing referral source options",
    "admin_settings" => "Admin settings page",
    "admin_data_exports" => "Full data export",
    "admin_usage_reports" => "Admin-only usage report"
  }.freeze

  def up
    FEATURES.each do |key, description|
      Feature.find_or_create_by!(key: key) do |f|
        f.admin_only = true
        f.description = description
      end
    end
  end

  def down
  end
end
