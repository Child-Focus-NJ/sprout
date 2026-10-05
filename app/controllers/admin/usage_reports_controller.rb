module Admin
  class UsageReportsController < ApplicationController
    before_action :require_admin!

    def show
      @metrics = UsageMetrics.new
    end
  end
end
