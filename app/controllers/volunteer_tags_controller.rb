class VolunteerTagsController < ApplicationController
  def create
    VolunteerTag.create!(title: params[:title])
    redirect_to system_management_path(tab: "tags"), notice: "Tag added."
  end

  def update
    VolunteerTag.find(params[:id]).update!(title: params[:title])
    redirect_to system_management_path(tab: "tags"), notice: "Tag updated."
  end

  def destroy
    VolunteerTag.find(params[:id]).destroy
    redirect_to system_management_path(tab: "tags"), notice: "Tag removed."
  end
end
