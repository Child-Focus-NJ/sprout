class SystemManagementController < ApplicationController
  def show
    @users = User.where.not(id: current_user.id)
    @recent_syncs = ExternalSyncLog
                      .completed
                      .where("completed_at > ?", 24.hours.ago)
                      .includes(:volunteer)
                      .order(completed_at: :desc)
  end

  def import
    file = params[:file]
    if file.present?
      VolunteerImportService.call(file.path)
      redirect_to system_management_path, notice: "Import complete."
    else
      redirect_to system_management_path, alert: "No file selected."
    end
  end
end
