class AddFieldsToInquiryFormSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :inquiry_form_submissions, :first_name, :string
    add_column :inquiry_form_submissions, :last_name, :string
    add_column :inquiry_form_submissions, :email, :string
    add_column :inquiry_form_submissions, :phone, :string
    add_column :inquiry_form_submissions, :county, :string
    add_column :inquiry_form_submissions, :how_did_you_hear, :string
    add_column :inquiry_form_submissions, :other_info, :string
    add_column :inquiry_form_submissions, :preferred_session_id, :bigint
    add_index :inquiry_form_submissions, :preferred_session_id
  end
end
