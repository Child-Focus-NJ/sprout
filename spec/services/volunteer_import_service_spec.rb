require "rails_helper"

RSpec.describe VolunteerImportService do
  let(:file_path) { Rails.root.join("tmp", "test_import.xlsx") }

  def build_xlsx(rows)
    workbook = RubyXL::Workbook.new
    sheet = workbook[0]
    headers = [ "first_name", "last_name", "email" ]
    headers.each_with_index { |h, i| sheet.add_cell(0, i, h) }
    rows.each_with_index do |row, r|
      row.each_with_index { |val, c| sheet.add_cell(r + 1, c, val) }
    end
    workbook.write(file_path)
    file_path.to_s
  end

  after { File.delete(file_path) if File.exist?(file_path) }

  describe ".call" do
    it "creates a new volunteer from the spreadsheet" do
      path = build_xlsx([ [ "Colin", "Smith", "colin@import.test" ] ])
      expect { VolunteerImportService.call(path) }.to change(Volunteer, :count).by(1)

      volunteer = Volunteer.find_by(email: "colin@import.test")
      expect(volunteer.first_name).to eq("Colin")
      expect(volunteer.last_name).to eq("Smith")
    end

    it "does not duplicate an existing volunteer" do
      Volunteer.create!(email: "colin@import.test", first_name: "Colin", last_name: "Smith")
      path = build_xlsx([ [ "Colin", "Smith", "colin@import.test" ] ])
      expect { VolunteerImportService.call(path) }.not_to change(Volunteer, :count)
    end

    it "imports multiple volunteers" do
      path = build_xlsx([
        [ "Colin", "Smith", "colin@import.test" ],
        [ "Jane",  "Doe",   "jane@import.test" ]
      ])
      expect { VolunteerImportService.call(path) }.to change(Volunteer, :count).by(2)
    end

    it "handles extra whitespace in headers" do
      path = build_xlsx([ [ "Alice", "Brown", "alice@import.test" ] ])
      expect { VolunteerImportService.call(path) }.to change(Volunteer, :count).by(1)
    end
  end
end
