class ApplicationDashboardController < ApplicationController
  def index
    @awaiting_submission = Volunteer.where(current_funnel_stage: :application_sent)
                                    .order(application_sent_at: :asc)
  end
end
