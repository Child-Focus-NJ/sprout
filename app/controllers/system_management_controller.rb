class SystemManagementController < ApplicationController
  def show
    @users = User.all
    @volunteers = Volunteer.all
    @recent_syncs = ExternalSyncLog.where(status: :completed)
                               .where("completed_at > ?", 24.hours.ago)
                               .includes(:volunteer)
                               .order(completed_at: :desc)
  end

  def import
    file = params[:file]
    if file.present?
      import_volunteers_from_xlsx(file.path)
      redirect_to system_management_path, notice: "Import complete."
    else
      redirect_to system_management_path, alert: "No file selected."
    end
  end

  private

  def import_volunteers_from_xlsx(path)
    require "roo"
    spreadsheet = Roo::Spreadsheet.open(path)
    sheet = spreadsheet.sheet(0)
    headers = sheet.row(1).map(&:to_s).map(&:strip)
    (2..sheet.last_row).each do |i|
      row = Hash[headers.zip(sheet.row(i))]
      Volunteer.find_or_create_by!(email: row["email"]) do |v|
        v.first_name = row["first_name"]
        v.last_name  = row["last_name"]
      end
    end
  end
end
