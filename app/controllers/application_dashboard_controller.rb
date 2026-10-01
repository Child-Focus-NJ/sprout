class ApplicationDashboardController < ApplicationController
  def index
    @metrics = DashboardMetrics.new
    @awaiting_submission = Volunteer.awaiting_application_submission
  end
end
