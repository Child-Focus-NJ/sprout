class ReminderFrequenciesController < ApplicationController
  def create
    ReminderFrequency.create!(title: params[:title])
    redirect_to system_management_path(tab: "frequencies"), notice: "Frequency added."
  end

  def update
    ReminderFrequency.find(params[:id]).update!(title: params[:title])
    redirect_to system_management_path(tab: "frequencies"), notice: "Frequency updated."
  end

  def destroy
    ReminderFrequency.find(params[:id]).destroy
    redirect_to system_management_path(tab: "frequencies"), notice: "Frequency removed."
  end
end
