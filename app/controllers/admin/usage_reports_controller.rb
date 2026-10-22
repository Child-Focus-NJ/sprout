module Admin
  class UsageReportsController < ApplicationController
    restrict_to_feature :admin_usage_reports

    def show
      @metrics = UsageMetrics.new
    end
  end
end
