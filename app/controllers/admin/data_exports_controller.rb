module Admin
  class DataExportsController < ApplicationController
    before_action :require_admin!

    def create
      log = DataExportLog.create!(
        user: current_user,
        trigger: :manual,
        status: :started,
        started_at: Time.current,
        filename: "sprout-full-export-#{Date.current.iso8601}.xlsx"
      )

      data = FullDataExport.call.string
      log.update!(status: :completed, completed_at: Time.current, byte_size: data.bytesize)

      send_data data,
        filename: log.filename,
        type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        disposition: "attachment"
    rescue StandardError => e
      log&.update!(status: :failed, completed_at: Time.current, error_message: e.message)
      raise
    end
  end
end
