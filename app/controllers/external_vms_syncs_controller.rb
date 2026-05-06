class ExternalVmsSyncsController < ApplicationController
  before_action :require_admin!

  def show
    load_synced_submissions
  end

  def create
    synced_volunteers = ExternalVmsSync.new.sync!
    redirect_to external_vms_sync_path, notice: "Synced #{synced_volunteers.size} external records."
  rescue KeyError
    redirect_to external_vms_sync_path, alert: "Set EXTERNAL_VMS_USERNAME and EXTERNAL_VMS_PASSWORD before syncing."
  rescue StandardError => e
    redirect_to external_vms_sync_path, alert: "External sync failed: #{e.message}"
  end

  private

  def load_synced_submissions
    @synced_submissions = InquiryFormSubmission.where(source: ExternalVmsSync::SOURCE_NAME)
                                               .includes(:volunteer)
                                               .order(updated_at: :desc)
                                               .limit(100)
    @last_sync = ExternalSyncLog.where(sync_direction: :inbound)
                                .where(sync_type: :pull)
                                .order(created_at: :desc)
                                .first
  end
end
