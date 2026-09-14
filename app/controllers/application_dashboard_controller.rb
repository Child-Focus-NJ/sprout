class ApplicationDashboardController < ApplicationController
  def index
    @awaiting_submission = Volunteer.awaiting_application_submission
  end
end
