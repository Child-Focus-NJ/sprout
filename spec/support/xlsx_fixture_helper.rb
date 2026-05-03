require "rubyXL"
require "rubyXL/convenience_methods"

workbook = RubyXL::Workbook.new
sheet = workbook[0]
sheet.add_cell(0, 0, "first_name")
sheet.add_cell(0, 1, "last_name")
sheet.add_cell(0, 2, "email")
sheet.add_cell(1, 0, "Colin")
sheet.add_cell(1, 1, "Smith")
sheet.add_cell(1, 2, "colin.smith@import.test")
workbook.write(Rails.root.join("spec/fixtures/files/volunteers.xlsx").to_s)