Given("the dashboard has volunteers in these stages:") do |table|
  table.hashes.each do |row|
    first_name, last_name = row["name"].split(" ", 2)
    Volunteer.create!(
      first_name: first_name,
      last_name: last_name,
      email: "#{row['name'].parameterize}@childfocusnj.org",
      current_funnel_stage: row["status"],
      application_sent_at: (2.days.ago if row["status"] == "application_sent")
    )
  end
end

When("I visit the dashboard") do
  visit application_dashboard_path
end

Then("the {string} tile should show {int}") do |label, value|
  tile = find(".stat-tile", text: label)
  expect(tile.find(".stat-tile__value")).to have_text(value.to_s, exact: true)
end

# Chartkick swaps each chart's placeholder for a <canvas> once Chart.js has loaded
# through importmap, so a canvas means the charts actually drew.
Then("the inquiries per month chart should be drawn") do
  expect(page).to have_css("#inquiries-by-month-chart canvas")
end

Then("the volunteers by stage chart should be drawn") do
  expect(page).to have_css("#volunteers-by-stage-chart canvas")
end

Given("an info session last week had {int} registrants and {int} checked in") do |registrants, checked_in|
  session = build(:information_session, scheduled_at: 1.week.ago)
  session.save!(validate: false)
  registrants.times do |index|
    create(:session_registration, information_session: session, status: index < checked_in ? :attended : :registered)
  end
end

Then("the conversion card should show {string}") do |text|
  expect(find("#conversion-funnel")).to have_text(text, normalize_ws: true)
end

Then("the attendance card should show {string}") do |text|
  expect(find("#session-attendance")).to have_text(text, normalize_ws: true)
end

Then("the awaiting submission list should be collapsed") do
  expect(find("#awaiting-submission summary")).to have_text("Awaiting submission 1", normalize_ws: true)
  expect(page).to have_no_css("#awaiting-submission .volunteer-list")
end

When("I open the awaiting submission dropdown") do
  open_awaiting_submission
end

Then("{string} should be in the awaiting submission list") do |name|
  expect(find("#awaiting-submission .volunteer-list")).to have_text(name)
end

Then("the new inquiries column should list {string}") do |names|
  expected = names.split(",").map(&:strip)
  within("#new-inquiries") do
    expect(page).to have_css(".new-inquiry-card", count: expected.size)
    expect(all(".new-inquiry-card__name").map(&:text)).to match_array(expected)
  end
end

When("I dismiss {string} from the new inquiries column") do |name|
  within("#new-inquiries .new-inquiry-card", text: name) { click_button "Dismiss" }
end

When("I clear all new inquiries") do
  within("#new-inquiries") { click_button "Clear all" }
end

Then("the new inquiries column should be empty") do
  within("#new-inquiries") do
    expect(page).to have_no_css(".new-inquiry-card")
    expect(page).to have_no_button("Clear all")
  end
end

When("{string} comes back after being inactive") do |name|
  first_name, last_name = name.split(" ", 2)
  volunteer = Volunteer.find_by!(first_name: first_name, last_name: last_name)
  volunteer.update!(current_funnel_stage: :inactive, inactive_reason: :no_response)
  volunteer.reactivate!
end

When("I click {string} in the new inquiries column") do |name|
  within("#new-inquiries") { click_link name }
end

Then("I should be on the profile for {string}") do |name|
  first_name, last_name = name.split(" ", 2)
  expect(page).to have_current_path(volunteer_path(Volunteer.find_by!(first_name: first_name, last_name: last_name)))
end
