

module VolunteerHelpers
  def find_or_create_volunteer_by_name(name)
    parts = name.split(" ", 2)
    first_name = parts[0] || "Unknown"
    last_name = parts[1] || ""
    email = "#{name.parameterize}@childfocusnj.org"

    Volunteer.find_by(email: email) || Volunteer.create!(
      email: email,
      first_name: first_name,
      last_name: last_name
    )
  end
end

World(VolunteerHelpers)

module DashboardHelpers
  # The awaiting submission list starts collapsed on the dashboard, so open it before looking inside
  def open_awaiting_submission
    panel = find("#awaiting-submission")
    panel.find("summary").click unless panel.matches_css?("[open]")
  end
end

World(DashboardHelpers)
