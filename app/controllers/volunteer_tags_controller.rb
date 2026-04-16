class VolunteerTagsController < ApplicationController
  def create
    VolunteerTag.create!(title: params[:title])
    redirect_to system_management_path
  end

  def destroy
    VolunteerTag.find(params[:id]).destroy
    redirect_to system_management_path
  end
end
