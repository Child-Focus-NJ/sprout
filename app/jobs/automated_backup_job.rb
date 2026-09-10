# Scheduled full-database export, written to disk under storage/backups/ for now
class AutomatedBackupJob < ApplicationJob
  queue_as :default

  BACKUPS_TO_KEEP = 30
  BACKUP_DIR = Rails.root.join("storage", "backups")

  def perform
    log = DataExportLog.create!(
      trigger: :scheduled,
      status: :started,
      started_at: Time.current,
      filename: "sprout-full-export-#{Date.current.iso8601}.xlsx"
    )

    data = FullDataExport.call.string
    store_backup(log.filename, data)

    log.update!(status: :completed, completed_at: Time.current, byte_size: data.bytesize)
    prune_old_backups
  rescue StandardError => e
    log&.update!(status: :failed, completed_at: Time.current, error_message: e.message)
    raise
  end

  private

  # This can be swapped for an S3 upload (Aws::StorageClient), nothing else would change
  # only using locally for now for dev purposes (+ it's free!)
  def store_backup(filename, data)
    FileUtils.mkdir_p(BACKUP_DIR)
    File.binwrite(BACKUP_DIR.join(filename), data)
  end

  def prune_old_backups
    DataExportLog.where(trigger: :scheduled, status: :completed)
                 .order(created_at: :desc)
                 .offset(BACKUPS_TO_KEEP)
                 .each do |old|
      FileUtils.rm_f(BACKUP_DIR.join(old.filename.to_s))
      old.destroy!
    end
  end
end
