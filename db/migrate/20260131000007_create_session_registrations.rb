class CreateSessionRegistrations < ActiveRecord::Migration[8.1]
  def change
    create_table :session_registrations do |t|
      t.references :volunteer, null: false, foreign_key: true
      t.references :information_session, null: false, foreign_key: true
      t.integer :status, default: 0, null: false
      t.datetime :registered_at
      t.datetime :checked_in_at
      t.text :cancellation_reason

      t.timestamps
    end

    add_index :session_registrations, [ :volunteer_id, :information_session_id ], unique: true, name: 'idx_session_registrations_volunteer_session'
    add_index :session_registrations, :status
  end
end
