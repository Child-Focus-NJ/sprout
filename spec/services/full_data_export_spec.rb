require "rails_helper"

RSpec.describe FullDataExport do
  let(:xlsx_path) { Rails.root.join("tmp", "full_data_export_spec.xlsx") }

  after { File.delete(xlsx_path) if File.exist?(xlsx_path) }

  def workbook_from(stream)
    File.binwrite(xlsx_path, stream.string)
    Roo::Spreadsheet.open(xlsx_path.to_s)
  end

  it "returns a StringIO holding an xlsx archive" do
    stream = described_class.call

    expect(stream).to be_a(StringIO)
    expect(stream.string[0, 2]).to eq("PK")
  end

  it "adds exactly one worksheet per exported model" do
    create(:user, role: :admin)
    create(:volunteer)

    book = workbook_from(described_class.call)

    expected_sheets = FullDataExport::MODELS.map { |model| model.table_name.first(31) }
    expect(book.sheets).to match_array(expected_sheets)
  end

  it "writes a header row of column names and a row per record" do
    create(:volunteer, email: "vera@example.org", first_name: "Vera", last_name: "Volunteer")

    sheet = workbook_from(described_class.call).sheet("volunteers")

    expect(sheet.row(1)).to eq(Volunteer.column_names)
    email_column = Volunteer.column_names.index("email") + 1
    emails = (2..sheet.last_row).map { |row| sheet.cell(row, email_column) }
    expect(emails).to include("vera@example.org")
  end

  it "produces a header-only sheet for an empty table" do
    sheet = workbook_from(described_class.call).sheet("notes")

    expect(sheet.row(1)).to eq(Note.column_names)
    expect(sheet.last_row).to eq(1)
  end

  it "serializes timestamps as ISO 8601 strings" do
    create(:volunteer)

    sheet = workbook_from(described_class.call).sheet("volunteers")
    created_column = Volunteer.column_names.index("created_at") + 1

    expect(sheet.cell(2, created_column)).to match(/\A\d{4}-\d{2}-\d{2}T/)
  end

  it "serializes jsonb columns as JSON, capped at Excel's cell limit" do
    create(:inquiry_form_submission, raw_data: { "answers" => "x" * 40_000 })

    sheet = workbook_from(described_class.call).sheet("inquiry_form_submissions")
    raw_data_column = InquiryFormSubmission.column_names.index("raw_data") + 1
    cell = sheet.cell(2, raw_data_column)

    expect(cell).to start_with('{"answers":"xxx')
    expect(cell.length).to eq(FullDataExport::MAX_CELL_LENGTH)
  end
end
