# Merge button on Admin > Possible Duplicates
class DuplicateMergesController < ApplicationController
  restrict_to_feature :system_management

  def create
    volunteers = Volunteer.where(id: [ params[:volunteer_id], params[:other_volunteer_id] ]).to_a
    return redirect_to(duplicates_tab, alert: "Couldn't find both volunteers.") unless volunteers.size == 2

    choices = params.fetch(:keep, {}).permit(*VolunteerMerge::CHOICES)
    kept = VolunteerMerge.new(*volunteers, choices: choices, user: current_user).call
    redirect_to duplicates_tab, notice: "Merged the two records into #{kept.full_name}'s profile."
  rescue ActiveRecord::RecordNotFound
    redirect_to duplicates_tab, alert: "Couldn't find both volunteers."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to duplicates_tab, alert: "Couldn't merge: #{e.record.errors.full_messages.to_sentence}"
  end

  private

  def duplicates_tab
    system_management_path(tab: "duplicates")
  end
end
