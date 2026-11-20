class CreateInquiryDismissals < ActiveRecord::Migration[8.1]
  def change
    # Staff see volunteers added after this time on their dashboard. Existing staff start from when
    # this runs, so nobody opens the dashboard to every past inquiry, and new staff from when they're added.
    add_column :users, :inquiry_notices_since, :datetime, null: false, default: -> { "CURRENT_TIMESTAMP" }

    # A row for each new inquiry a staff member has dismissed with the ×
    create_table :inquiry_dismissals do |t|
      t.references :user, null: false, foreign_key: true
      t.references :volunteer, null: false, foreign_key: true
      t.timestamps
    end
    add_index :inquiry_dismissals, [ :user_id, :volunteer_id ], unique: true
  end
end
