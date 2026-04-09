class ApplicationDashboardController < ApplicationController
  before_action :require_admin!

  def index
    @awaiting_submission = Volunteer.awaiting_application_submission
  end
end
