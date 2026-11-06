class RequireVolunteerInquiryDates < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE volunteers SET inquiry_date = created_at WHERE inquiry_date IS NULL"
    change_column_null :volunteers, :inquiry_date, false
  end

  def down
    change_column_null :volunteers, :inquiry_date, true
  end
end
