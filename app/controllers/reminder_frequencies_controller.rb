class ReminderFrequenciesController < ApplicationController
  def create
    ReminderFrequency.create!(title: params[:title])
    redirect_to system_management_path
  end

  def destroy
    ReminderFrequency.find(params[:id]).destroy
    redirect_to system_management_path
  end
end
