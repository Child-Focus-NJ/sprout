class CreateVolunteers < ActiveRecord::Migration[8.1]
  def change
    create_table :volunteers do |t|
      # Core identification
      t.string :external_id
      t.datetime :external_synced_at

      # Personal info
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.string :phone
      t.integer :preferred_contact_method, default: 0, null: false

      # Funnel tracking
      t.integer :current_funnel_stage, default: 0, null: false
      t.datetime :inquiry_date
      t.datetime :first_session_attended_at

      # Inactive tracking
      t.datetime :became_inactive_at
      t.integer :inactive_reason
      t.integer :weeks_at_inactivation

      # Reactivation tracking
      t.datetime :reactivated_at
      t.integer :reactivation_count, default: 0, null: false

      # Application tracking
      t.datetime :application_sent_at
      t.datetime :application_submitted_at

      # Referral tracking
      t.references :referral_source, foreign_key: true
      t.references :referred_by_volunteer, foreign_key: { to_table: :volunteers }

      t.timestamps
    end

    add_index :volunteers, :email, unique: true
    add_index :volunteers, :external_id
    add_index :volunteers, :current_funnel_stage
    add_index :volunteers, :inquiry_date
    add_index :volunteers, :became_inactive_at
  end
end
