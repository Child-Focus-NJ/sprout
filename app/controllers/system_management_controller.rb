class SystemManagementController < ApplicationController
  TABS = %w[frequencies tags employees referral_sources].freeze

  def show
    @tab = TABS.include?(params[:tab]) ? params[:tab] : "frequencies"
    @users = User.where.not(id: current_user.id).order(:last_name, :first_name)
    @reminder_frequencies = ReminderFrequency.order(:title)
    @volunteer_tags = VolunteerTag.order(:title)
    @referral_sources = ReferralSource.order(:name)
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
