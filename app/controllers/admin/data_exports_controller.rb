module Admin
  class DataExportsController < ApplicationController
    before_action :require_admin!

    def create
      filename = "sprout-full-export-#{Date.current.iso8601}.xlsx"
      stream = FullDataExport.call

      if Rails.env.test?
        FileUtils.mkdir_p(Rails.root.join("tmp", "test_downloads"))
        File.binwrite(Rails.root.join("tmp", "test_downloads", filename), stream.string)
        head :ok
      else
        send_data stream.string,
          filename: filename,
          type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
          disposition: "attachment"
      end
    end
  end
end
