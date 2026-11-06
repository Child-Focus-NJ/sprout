class RenameNjCountiesToVicinage < ActiveRecord::Migration[8.1]
  def change
    rename_table :nj_counties, :vicinages
    rename_column :inquiry_form_submissions, :nj_county_id, :vicinage_id
    rename_column :volunteers, :nj_county_id, :vicinage_id
  end
end
