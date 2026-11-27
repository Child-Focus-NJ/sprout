# "Not a duplicate" on Admin > Possible Duplicates: staff checked the pair, so it stops showing
class DuplicateDismissalsController < ApplicationController
  restrict_to_feature :system_management

  def create
    volunteers = Volunteer.where(id: [ params[:volunteer_id], params[:other_volunteer_id] ]).order(:id).to_a
    return redirect_to(duplicates_tab, alert: "Couldn't find both volunteers.") unless volunteers.size == 2

    DuplicateDismissal.dismiss!(*volunteers, user: current_user)
    redirect_to duplicates_tab,
                notice: "#{volunteers.map(&:full_name).to_sentence} won't show as possible duplicates again."
  end

  private

  def duplicates_tab
    system_management_path(tab: "duplicates")
  end
end
