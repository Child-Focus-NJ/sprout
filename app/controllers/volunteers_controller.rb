class VolunteersController < ApplicationController
  before_action :set_volunteer, only: [ :show, :update_status, :send_application, :mark_submitted ]

  def show
  end

  def update_status
    @volunteer.change_status!(params[:status], user: current_user)
    redirect_to volunteer_path(@volunteer)
  end

  def send_application
    if @volunteer.application_sent_at.present?
      redirect_to volunteer_path(@volunteer), alert: "Application was already sent"
    else
      @volunteer.change_status!(:application_sent, user: current_user)
      @volunteer.update!(application_sent_at: Time.current)
      redirect_to volunteer_path(@volunteer), notice: "Application email queued for #{@volunteer.full_name}"
    end
  end

  def mark_submitted
    @volunteer.update!(application_submitted_at: Time.current)
    @volunteer.change_status!(:applied, user: current_user)
    redirect_to volunteer_path(@volunteer), notice: "Application recorded. Staff have been notified."
  end

  private

  def set_volunteer
    @volunteer = Volunteer.find(params[:id])
  end
end
