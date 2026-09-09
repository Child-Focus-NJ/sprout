# Builds a single Excel workbook containing every row of every table in our db,
# one worksheet per table, for the admin "Export All Data" download.

class FullDataExport
  require "caxlsx"

  # list of models to export
  MODELS = [
    ReferralSource,
    NjCounty,
    ReminderFrequency,
    VolunteerTag,
    SystemSetting,
    User,
    Volunteer,
    InformationSession,
    SessionRegistration,
    Note,
    StatusChange,
    Communication,
    CommunicationTemplate,
    ScheduledReminder,
    InquiryFormSubmission,
    ExternalSyncLog
  ].freeze

  # Excel's limit on the number of characters in a single cell.
  MAX_CELL_LENGTH = 32_767

  def self.call
    new.to_stream
  end

  # Returns a StringIO of the .xlsx file, ready for send_data.
  def to_stream
    package = Axlsx::Package.new
    MODELS.each { |model| add_model_sheet(package.workbook, model) }
    package.to_stream
  end

  private

  def add_model_sheet(workbook, model)
    columns = model.column_names

    workbook.add_worksheet(name: sheet_name(model.table_name)) do |sheet|
      sheet.add_row columns
      model.find_each(batch_size: 1_000) do |record|
        sheet.add_row columns.map { |column| cell_value(record[column]) }
      end
    end
  end

  # Worksheet names must be <= 31 characters and cannot contain : \ / ? * [ ] per excel rules
  def sheet_name(table_name)
    table_name.gsub(%r{[:\\/?*\[\]]}, "_").first(31)
  end

  def cell_value(value)
    case value
    when nil
      nil
    when Time, DateTime, ActiveSupport::TimeWithZone, Date
      value.iso8601
    when Hash, Array
      value.to_json
    else
      value.to_s.slice(0, MAX_CELL_LENGTH)
    end
  end
end
