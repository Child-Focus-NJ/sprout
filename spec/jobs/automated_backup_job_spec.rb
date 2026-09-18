require "rails_helper"

RSpec.describe AutomatedBackupJob do
  let(:backup_dir) { AutomatedBackupJob::BACKUP_DIR }

  after { FileUtils.rm_rf(backup_dir) }

  it "writes a workbook to storage/backups and logs a completed scheduled export" do
    create(:volunteer, email: "grace@example.org")

    expect { described_class.perform_now }.to change(DataExportLog, :count).by(1)

    log = DataExportLog.last
    expect(log).to have_attributes(trigger: "scheduled", status: "completed", user: nil)
    expect(log.byte_size).to be_positive
    expect(log.completed_at).to be_present

    file = backup_dir.join(log.filename)
    expect(file).to exist

    workbook = Roo::Spreadsheet.open(file.to_s)
    expect(workbook.sheets).to include("volunteers")
    expect(workbook.sheet("volunteers").to_a.flatten).to include("grace@example.org")
  end

  it "records a failed log and re-raises when the export blows up" do
    allow(FullDataExport).to receive(:call).and_raise("boom")

    expect { described_class.perform_now }.to raise_error("boom")

    expect(DataExportLog.last).to have_attributes(status: "failed", error_message: "boom")
  end

  it "keeps only the most recent BACKUPS_TO_KEEP backups" do
    stub_const("AutomatedBackupJob::BACKUPS_TO_KEEP", 2)

    4.times { |i| travel_to(Time.zone.local(2026, 9, 10 + i, 2)) { described_class.perform_now } }

    expect(DataExportLog.where(trigger: :scheduled).count).to eq(2)
    expect(Dir[backup_dir.join("*.xlsx")].length).to eq(2)
  end
end
