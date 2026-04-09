# Restores denormalized inquiry fields expected by reporting and older schema dumps.
# Submissions still store a copy in raw_data for flexibility.
class AddInquiryFieldsToInquiryFormSubmissions < ActiveRecord::Migration[8.1]
  def change
    change_table :inquiry_form_submissions, bulk: true do |t|
      t.string :county
      t.string :email
      t.string :first_name
      t.string :how_did_you_hear
      t.string :last_name
      t.string :other_info
      t.string :phone
    end

    add_reference :inquiry_form_submissions, :preferred_session, foreign_key: { to_table: :information_sessions }, null: true
  end
end
