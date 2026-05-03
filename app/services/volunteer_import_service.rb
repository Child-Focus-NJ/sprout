class VolunteerImportService
  require "roo"

  def self.call(path)
    new(path).import
  end

  def initialize(path)
    @path = path
  end

  def import
    sheet = Roo::Spreadsheet.open(@path).sheet(0)
    headers = sheet.row(1).map { |h| h.to_s.strip }

    (2..sheet.last_row).each do |i|
      row = headers.zip(sheet.row(i)).to_h
      Volunteer.find_or_create_by!(email: row["email"]) do |v|
        v.first_name = row["first_name"]
        v.last_name  = row["last_name"]
      end
    end
  end
end
